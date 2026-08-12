# Storage Architecture

## Overview

WVU Knapsack uses **three separate storage systems** to persist different types of data. Understanding where data actually lives is critical for backups, restores, and deployments.

| Component | Storage Location | Purpose | Persistence |
|---|---|---|---|
| **Metadata** | PostgreSQL (`./data/db`) | Records, file references, tenant config | Database tables |
| **Search Index** | Solr (`./data/solr`) | Full-text search, facets | Inverted index |
| **Binary Files** | Disk (`./data/storage/files/`) | Uploaded files, derivatives, IIIF images | Filesystem |
| **Code** | Git repo (`.`) | Application source + hyrax-webapp submodule | Git history |

---

## The Problem: Original Setup

The original `docker-compose.production.original.yml` had this fatal flaw:

```yaml
volumes:
  - .:/app/samvera                    # Entire git repo mounted
  - node_modules:/...                 # Only named volumes here
  - uploads:/...
  - assets:/...
  - cache:/...
  # NO explicit mount for /app/samvera/hyrax-webapp/storage
```

**What this meant:**
- The git repository (`.`) was mounted at `/app/samvera`
- No separate mount for `/app/samvera/hyrax-webapp/storage`
- Hyku's Valkyrie disk adapter wrote files **inside the git repo directory**
- Files were ephemeral (lost on container restart, git checkout, or `git clean`)

**Why it happened:**
- No one realized Hyku stored actual file data on disk (thought it was all Fedora or PostgreSQL)
- The `.:/app/samvera` bind mount was for code, not data
- Storage path conflicts were invisible until tested

**Symptoms:**
- Drive filled up during testing (files accumulated in git repo, couldn't be cleaned)
- Files disappeared on container restart or fresh checkout
- No clear understanding of the data architecture

---

## Current Setup (Fixed)

The current `docker-compose.production.yml` properly separates code and data:

```yaml
x-app: &app
  volumes:
    # Code: git repo only
    - .:/app/samvera
    
    # Data: explicit mounts away from code
    - ./data/bundle:/usr/local/bundle
    - ./data/node_modules:/app/samvera/hyrax-webapp/node_modules
    - ./data/uploads:/app/samvera/hyrax-webapp/public/uploads
    - ./data/assets:/app/samvera/hyrax-webapp/public/assets
    - ./data/tmp:/app/samvera/hyrax-webapp/tmp
    - ./data/logs/rails:/app/samvera/hyrax-webapp/log
    - ./data/ingest:/app/samvera/ingest
    - ./data/storage:/app/samvera/hyrax-webapp/storage    # ← Binary files (critical)
    # ... more data mounts
```

**Why this works:**
- ✅ Code lives in git repo (`.`) — can be updated without touching data
- ✅ Data lives in `./data/` — persists across restarts, deployments, code updates
- ✅ On production, `./data/` mounts to VAST (network storage) — backed up separately
- ✅ Clear separation of concerns

---

## Where Each Type of Data Lives

### 1. Metadata (PostgreSQL)

**Location:** `./data/db/`

**What it contains:**
- Work records (title, creator, description)
- File references (which `FileMetadata` objects point to which files)
- Tenant configuration (`Account` records)
- User accounts and permissions
- All metadata Hyku queries

**Loss impact:** 
- ❌ CRITICAL — all records disappear, no way to list what files exist
- Uploaded files become orphaned (metadata lost, files unrecoverable)

**Backup:** Include in regular PostgreSQL backups

---

### 2. Binary Files (Valkyrie Disk Adapter)

**Location:** `./data/storage/files/`

**What it contains:**
- Original uploaded files (PDFs, images, documents)
- Derivative files (thumbnails, IIIF tiles, resized images)
- File metadata cached by Valkyrie

**How it works:**
```
Hyku receives upload
  ↓
Creates FileMetadata record in PostgreSQL (metadata)
  ↓
Writes binary to ./data/storage/files/{hash}/filename (data)
  ↓
Returns file ID for search/display
```

**Loss impact:**
- ❌ CRITICAL — all uploaded content disappears
- Metadata remains but references broken files
- IIIF viewer returns 500 errors
- Downloads fail

**Why it's critical:**
- This is NOT a cache — it's the source of truth for file content
- Regenerating derivatives requires original file (can't recreate from nothing)

**Backup:** Include in regular filesystem backups

---

### 3. Search Index (Solr)

**Location:** `./data/solr/`

**What it contains:**
- Inverted index for full-text search
- Facets and document structure
- Built from PostgreSQL metadata

**Loss impact:**
- ⚠️ RECOVERABLE — search/browse broken, but data not lost
- Run `reindex` task to rebuild from PostgreSQL

**Backup:** Optional (can be regenerated)

---

### 4. Source Code (Git)

**Location:** `.` (git repository root)

**What it contains:**
- WVU Knapsack customizations
- `hyrax-webapp/` submodule (Hyku core — read-only)
- Configuration templates

**Loss impact:**
- ❌ CRITICAL — lose codebase, can't deploy or update
- Can't recover custom features if git is lost

**Backup:** Git repository (version control is the backup)

---

## Critical Issue: Submodule Updates

### Why it matters

The `hyrax-webapp/` submodule is a read-only reference to Hyku core. When updating to a new Hyku version:

```bash
cd hyrax-webapp
git fetch origin
git checkout v5.3.0
cd ..
git add hyrax-webapp
git commit -m "Bump Hyku to v5.3.0"
```

**With the original setup** (files in git repo):
- ❌ Risky: Git operations might touch `/app/samvera/hyrax-webapp/storage/`
- ❌ If storage is inside git history, checkout could overwrite uploaded files
- ❌ No clear boundary between code and data

**With current setup** (files in `./data/`):
- ✅ Safe: Submodule updates only touch code, never touch `./data/`
- ✅ Git operations are isolated from running data
- ✅ Can roll back code without affecting uploaded files

### Safe update procedure

```bash
# 1. Stop the stack (optional, but recommended for safety)
sh down.sh

# 2. Update submodule (touch only code)
cd hyrax-webapp
git fetch origin
git checkout v5.3.0
cd ..

# 3. Commit the change
git add hyrax-webapp
git commit -m "Bump Hyku to v5.3.0"
git push origin main

# 4. Restart with new code
sh up.sh

# 5. Run migrations and setup
docker compose -f docker-compose.production.yml exec web sh /app/samvera/scripts/setup.sh
```

**Data in `./data/` is untouched throughout this process.**

---

## Backup & Restore Strategy

### What to back up

All of `./data/`:

```bash
./data/db/           # PostgreSQL (critical)
./data/storage/      # Uploaded files (critical)
./data/solr/         # Solr index (optional, can regenerate)
./data/fcrepo/       # Fedora objects (usually empty in disk-adapter setup)
./data/redis/        # Session/job state (optional, ephemeral)
```

**On production:** `./data/` typically mounts to VAST (network storage), which is backed up by IT.

### Restoring from backup

**Full restore** (after catastrophic failure):

```bash
# 1. Stop the stack
sh down.sh

# 2. Restore ./data from backup
# (depends on your backup system)
rsync -av /backup/data/ ./data/

# 3. Verify ownership (should be uid 1001)
ls -la ./data/

# 4. Start the stack
sh up.sh

# 5. Verify database is accessible
docker compose -f docker-compose.production.yml exec db psql -U postgres -d hyku -c "SELECT COUNT(*) FROM orm_resources;"

# 6. Check file storage
docker compose -f docker-compose.production.yml exec web ls -la /app/samvera/hyrax-webapp/storage/files/ | head
```

**Database-only restore** (if only PostgreSQL is corrupt):

```bash
sh down.sh
rm -rf ./data/db

# Restore just the DB directory
rsync -av /backup/data/db/ ./data/db/

sh up.sh
```

**File-only restore** (if only files are lost):

```bash
# Restore just the storage directory (careful — don't overwrite metadata)
rsync -av /backup/data/storage/ ./data/storage/

# Verify in browser — files should appear
```

---

## Volume Mount Architecture by Environment

### Local Development (Stack Car)

```yaml
volumes:
  - .:/app/samvera                       # Code
  - node_modules:/app/samvera/hyrax-webapp/node_modules:cached
  - uploads:/...
  - assets:/...
  # Data is ephemeral in Stack Car (named volumes, not bind mounts)
```

**Note:** Data is lost when you run `sc down -v`. This is intentional for local dev.

---

### Local Production Smoke Test

```yaml
volumes:
  - ./data/bundle:/usr/local/bundle:cached      # Bind mount (local disk)
  - ./data/node_modules:/app/samvera/hyrax-webapp/node_modules:cached
  - ./data/storage:/app/samvera/hyrax-webapp/storage:cached  # Files (critical)
  # All other data in ./data (db, solr, etc.)
```

**Note:** Mirrors production config. Use `./scripts/cleanup-prod.sh` to wipe and restart.

---

### Production VM

```yaml
volumes:
  - ./data/bundle:/usr/local/bundle:cached           # Bind mount → local disk
  - ./data/storage:/app/samvera/hyrax-webapp/storage:cached  # Bind mount → VAST (persistent)
  - ./data/db:/var/lib/postgresql/data               # Bind mount → VAST
  - ./data/solr:/var/solr/data                       # Bind mount → VAST
  # All other data in ./data, which on VAST
```

**Note:** On production, `./data/` typically mounts to VAST via NFS or SMB. This is configured outside of Docker (via `/etc/fstab` or similar). The entire `./data/` tree is backed up by IT infrastructure.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| IIIF viewer returns 500 | Files missing from `./data/storage/files/` | Restore from backup or re-upload files |
| Search doesn't work but downloads do | Solr index corrupted | `docker compose exec web bundle exec rails hyku:solr:reindex` |
| Uploads fail with "Permission denied" | `./data/storage/` owned by wrong user | `chmod -R 777 ./data/storage/` (or restore from backup with correct ownership) |
| Files disappear after `docker compose down` | Using `docker compose down -v` (removes named volumes) | Data persists in bind mounts (`./data/`) — down without `-v` to keep it |
| Cannot update submodule | Storage path conflict from original setup | Confirm storage is in `./data/`, not in git repo |
| Metadata lost but files still exist | PostgreSQL backup restored incorrectly | Restore `./data/db/` only if sure DB is corrupt; verify files first |

---

## Key Takeaways

1. **Files are NOT in Fedora** — they live in `./data/storage/files/` on disk
2. **Storage mount is mandatory** — without it, files are ephemeral
3. **Code and data are separate** — code updates don't touch uploaded files
4. **Backups must include both** — metadata (PostgreSQL) AND files (disk)
5. **Submodule updates are safe** — because files are outside the git repo
6. **On production, `./data/` is on VAST** — persisted and backed up by IT

---

## References

- [HYKU_BUILD_GUIDE.md](HYKU_BUILD_GUIDE.md) — Full deployment guide
- [docker-compose.production.yml](docker-compose.production.yml) — Volume mount config
- [Hyrax Valkyrie Storage](https://github.com/samvera/hyrax/wiki/Valkyrie-Storage-Adapter) — Storage adapter docs
