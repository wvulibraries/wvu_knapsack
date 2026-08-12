# wvu_knapsack Developer Guide

This repo is a **HykuKnapsack** — a Rails engine that customises [Hyku](https://github.com/samvera/hyku). The Hyku core lives in the `hyrax-webapp/` git submodule and must not be edited directly. All WVU customisations live in this repo.

There are three workflows covered here:

| Workflow | Who | Script |
|---|---|---|
| [Local dev with Stack Car](#1-local-development-stack-car) | Developers | `up.sc.local.sh` / `down.sc.local.sh` |
| [Local production smoke test](#2-local-production-smoke-testing) | Developers | `docker-compose.local.yml` |
| [VM production deployment](#3-vm-production-deployment) | DevOps | `up.sh` / `down.sh` |

---

## Understanding Storage Architecture

⚠️ **Critical concept:** Hyku stores uploaded files on disk (not Fedora), and this folder must be explicitly mounted to persist across restarts and deployments.

See **[STORAGE_ARCHITECTURE.md](STORAGE_ARCHITECTURE.md)** for:
- Where each type of data lives (metadata, files, search index)
- Why the storage mount is critical
- How the original setup caused data loss
- Safe backup/restore procedures
- Implications for submodule updates

---

## Repository Layout

```
wvu_knapsack/
├── hyrax-webapp/                  ← git submodule (Hyku core — do not edit)
├── app/                           ← WVU overrides: models, views, controllers
├── config/
│   ├── initializers/
│   │   ├── host_authorization.rb  ← allows *.lib.wvu.edu + HYKU_EXTRA_HOSTS
│   │   └── session_store_override.rb ← fixes CSRF over HTTP (local testing)
│   └── ...
├── solr-setup/
│   └── security.json              ← Solr ZooKeeper auth config
├── scripts/
│   └── setup.sh                   ← idempotent one-time setup (DB + Solr + tenant)
├── startup-solr.sh                ← custom SolrCloud startup script
├── docker-compose.local.yml       ← local production smoke test (Mac arm64 — pulls GHCR images)
├── docker-compose.production.yml  ← VM production compose (RHEL amd64 — builds locally)
├── .env.production.example        ← committed template (web / worker / initialize_app)
├── .env.db.example                ← committed template (postgres container)
├── .env.redis.example             ← committed template (redis container)
├── .env.solr.example              ← committed template (solr container)
├── .env.fedora.example            ← committed template (fcrepo container)
├── .env.production                ← gitignored — web/worker/initialize_app vars
├── .env.db                        ← gitignored — postgres container vars
├── .env.redis                     ← gitignored — redis container vars
├── .env.solr                      ← gitignored — solr container vars
├── .env.fedora                    ← gitignored — fcrepo JAVA_OPTS (contains DB password)
├── .env.development               ← Stack Car local dev overrides
├── up.sc.local.sh                ← rebuild + start with Stack Car (dev)
├── down.sc.local.sh              ← stop Stack Car stack
├── up.prod.local.sh              ← start local production smoke test (Mac arm64)
├── down.prod.local.sh            ← stop local production smoke test
├── up.sh                         ← pull + start production stack (VM)
└── down.sh                       ← stop production stack (VM)
```

**APP_NAME convention:** always use hyphens (`wvu-knapsack`), never underscores. DNS hostname labels allow only `[a-z0-9-]` and Rails 7.2 `HostAuthorization` enforces this before consulting the allowed list. The development and production configs both follow this convention.

---

## 1. Local Development (Stack Car)

Stack Car (`sc`) is the standard Hyku local dev tool. It starts a Traefik proxy that provides `*.localhost.direct` wildcard HTTPS routing.

### Prerequisites

- Docker Desktop running
- Stack Car installed: `gem install stack_car` (or follow notch8/stack_car README)
- Stack Car proxy running: `sc proxy up`

Verify the proxy is up at https://traefik.localhost.direct/dashboard/#/

### Environment

`.env.development` is already committed with the correct Stack Car values:

```bash
APP_NAME=wvu-knapsack
HYKU_ADMIN_HOST="admin-${APP_NAME}.localhost.direct"
HYKU_DEFAULT_HOST="%{tenant}-${APP_NAME}.localhost.direct"
HYKU_MULTITENANT=true
HYRAX_FLEXIBLE=false
```

Stack Car reads this automatically. **Do not set `APP_NAME` in `.env`** — Stack Car derives it from the folder name.

### First-time setup

```bash
# 1. Ensure submodule is initialised
git submodule update --init --recursive

# 2. Start the stack (builds automatically on first run)
sc up -d

# 3. Watch initialization — wait for "Listening on http://0.0.0.0:3000"
sc logs web -f
```

### Day-to-day: start / stop

```bash
# Start (rebuilds web + worker from scratch, then sc up -d)
sh up.sc.local.sh

# Stop
sh down.sc.local.sh
```

`up.sc.local.sh` runs `docker compose build --no-cache web worker` then `sc up -d`.
This ensures a clean build — useful after gem or knapsack code changes.

For quick iteration where you don't need a full rebuild:

```bash
sc up -d          # start existing images
sc logs web -f    # watch logs
sc down           # stop
```

### Accessing the application

| URL | What |
|---|---|
| `https://admin-wvu-knapsack.localhost.direct` | Superadmin interface |
| `https://admin-wvu-knapsack.localhost.direct/users/sign_in` | Login page |
| `https://{tenant}-wvu-knapsack.localhost.direct` | Tenant frontend |

The database seeds automatically create the superadmin account. Default credentials come from the `INITIAL_ADMIN_EMAIL` / `INITIAL_ADMIN_PASSWORD` env vars (see `hyrax-webapp/.env`).

To create a superadmin manually:

```bash
sc exec rake hyku:superadmin:create
```

### Running commands inside the container

```bash
sc sh                                    # open a shell
sc exec bundle exec rails console        # Rails console
sc exec bundle exec rails db:migrate     # run migrations
sc exec bundle exec rspec spec/path      # run a spec
```

### Branch switching

Always remove database volumes when switching branches — seeds use the `APP_NAME` domain and a stale DB causes routing errors:

```bash
sc down
docker compose down -v     # -v removes volumes
git checkout <branch>
git submodule update --recursive
sh up.sc.local.sh
```

### Troubleshooting Stack Car

| Symptom | Fix |
|---|---|
| `https://admin-wvu-knapsack.localhost.direct` unreachable | `sc proxy up`, then check https://traefik.localhost.direct/dashboard |
| `Apartment::TenantNotFound` | DB seeded with wrong APP_NAME — `docker compose down -v` and restart |
| Puma not starting | Check `sc logs web -f` — look for bundle errors or migration failures |
| Port 3000 already in use | `lsof -i :3000` — kill the process or stop the production stack |
| `docker-compose.override.yml` with `sleep infinity` | Remove or rename it — it prevents Puma from starting |

### Nuclear Option — complete wipe and rebuild

Use this when nothing else works: volumes in a bad state, images corrupt, or you just want a guaranteed clean slate. Stack Car uses **named Docker volumes** (not `./data` bind mounts) — this script removes them safely scoped to this project only.

```bash
sh scripts/cleanup-dev.sh

# Then restart:
sh up.sc.local.sh
```

---

## 2. Local Production Smoke Testing

Use this to validate the production Docker image and config **before** deploying to the VM. It uses `docker-compose.local.yml` which pulls the pre-built arm64 GHCR images — no local build required on Mac.

This workflow does **not** use Stack Car. It runs on port 3000 and uses `lvh.me` for wildcard DNS (`*.lvh.me` → `127.0.0.1`, no HSTS, safe for plain HTTP).

> **Why not localhost.direct?** `localhost.direct` is under HSTS preload — browsers force HTTPS even on port 3000. `lvh.me` has no HSTS and works with plain HTTP.

### Prerequisites

- Docker Desktop running
- Stack Car proxy **not** required (but can be running — different port)
- No DNS changes needed — `lvh.me` is public

### Step 1: Create env files

Five env files are required — one for the Rails app and one per infrastructure container:

```bash
cp .env.production.example .env.production
cp .env.db.example        .env.db
cp .env.redis.example     .env.redis
cp .env.solr.example      .env.solr
cp .env.fedora.example    .env.fedora
```

Each file is gitignored (`.env.*`). The `.example` counterparts are committed so DevOps knows what to create. **If you change `POSTGRES_PASSWORD` in `.env.db` you must also update `DB_PASSWORD` in `.env.production` and the `fcrepo.postgresql.password` value inside `JAVA_OPTS` in `.env.fedora` — all three must match.** Similarly, `REDIS_PASSWORD` in `.env.redis` must match the password embedded in `REDIS_URL` in `.env.production`.

> ⚠️ **Postgres password change requires a data wipe.** `POSTGRES_PASSWORD` is only read by the postgres image during **first initialization of an empty `./data/db`**. Once the cluster exists on disk, changing `.env.db` has no effect — postgres still requires the original password. If you change the password after a prior run, you must wipe `./data/db` (run the cleanup script) so postgres reinitializes with the new password. Rails will otherwise fail to connect with `FATAL: password authentication failed`.

The example already has sensible defaults. For local smoke testing make sure these are set in `.env.production`:

```env
# Routing
HYKU_ROOT_HOST=lvh.me
HYKU_ADMIN_HOST=admin-wvu-knapsack.lvh.me
HYKU_DEFAULT_HOST=%{tenant}-wvu-knapsack.lvh.me
HYKU_EXTRA_HOSTS=.lvh.me

# Allow plain HTTP (no SSL proxy locally)
DISABLE_FORCE_SSL=true

# Serve assets directly from Puma (no Nginx)
RAILS_SERVE_STATIC_FILES=true
```

### Step 2: Start

```bash
docker compose -f docker-compose.local.yml up -d
```

Watch startup in order:

```bash
# ZooKeeper + Solr (wait for SolrCloud to be healthy)
docker compose -f docker-compose.local.yml logs -f zoo solr

# Infrastructure: db, redis, fcrepo, fits start in parallel — check they're all up
docker compose -f docker-compose.local.yml ps

# initialize_app: Solr configset upload, DB migrate/seed, bundle install (~2 min)
docker compose -f docker-compose.local.yml logs -f initialize_app

# Web: wait for "Listening on http://0.0.0.0:3000"
docker compose -f docker-compose.local.yml logs -f web
```

### Step 3: Run one-time setup (includes asset precompilation)

```bash
docker compose -f docker-compose.local.yml exec web sh /app/samvera/scripts/setup.sh
```

This is idempotent — safe to re-run. It handles:
1. DB create → migrate or schema:load (detects existing tables)
2. DB seed (creates superadmin from `INITIAL_ADMIN_EMAIL` / `INITIAL_ADMIN_PASSWORD`)
3. Optionally creates first repository tenant from `HYKU_FIRST_TENANT_NAME` / `HYKU_FIRST_TENANT_CNAME`

### Step 5: Test in browser

| URL | What |
|---|---|
| `http://admin-wvu-knapsack.lvh.me:3000` | Superadmin splash |
| `http://admin-wvu-knapsack.lvh.me:3000/users/sign_in` | Login |
| `http://{tenant}-wvu-knapsack.lvh.me:3000` | Tenant frontend |

Login with `INITIAL_ADMIN_EMAIL` / `INITIAL_ADMIN_PASSWORD` (default: `admin@example.com` / `changeme`).

### Stopping / resetting

```bash
# Stop without removing data
docker compose -f docker-compose.local.yml down

# Full reset — removes all data
docker compose -f docker-compose.local.yml down
rm -rf ./data
```

### Nuclear Option — complete wipe and rebuild

Use this when nothing else works: containers won't start, images are corrupt, or you want a guaranteed clean slate. This stack uses **bind mounts in `./data/`** — not named volumes.

```bash
sh scripts/cleanup-prod.sh

# Then restart:
docker compose -f docker-compose.local.yml up -d
docker compose -f docker-compose.local.yml logs -f initialize_app
docker compose -f docker-compose.local.yml exec web sh /app/samvera/scripts/setup.sh
```

> **Warning:** This permanently deletes the database, Solr index, Fedora objects, and all uploaded files. There is no undo.

### Tips

**Applying `.env.production` changes:** always use `up -d`, not `restart`:
```bash
docker compose -f docker-compose.local.yml up -d --no-deps web worker
```
`restart` reuses the cached environment and does NOT re-read `env_file`.

**Check container status:**
```bash
docker compose -f docker-compose.local.yml ps
```

---

## 3. VM Production Deployment

### Step 0: Provision the VM with Ansible

The `ansible/` directory contains a playbook that installs Docker, Nginx, SSL certificates, GHCR login, and user accounts on the VM. Run this **from your laptop** before doing anything on the VM itself.

1. Read **`ansible/README.md`** — it documents required files in `ansible/files/` and vault setup.
2. Edit `ansible/inventory.ini` with the target host and SSH user.
3. Run:

```bash
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml --ask-vault-pass -e @ansible/ghcr-token.vault.yml
```

After the playbook completes, Docker, Nginx, and GHCR login are configured on the VM. Continue with Step 1 on the VM.

### Prerequisites

- **Red Hat Enterprise Linux** VM with Docker CE and the Docker Compose v2 plugin installed
  - Install Docker CE from Docker's official RHEL repo (not the RHEL-packaged `podman`)
  - The Compose v2 plugin ships as `docker compose` (space, not hyphen) — `up.sh` / `down.sh` use this form
  - SELinux is enforcing by default on RHEL; after cloning the repo, label the data
    directory so containers can read/write it:
    ```bash
    mkdir -p ./data
    sudo chcon -Rt svirt_sandbox_file_t ./data
    ```
    Run this once before the first `sh up.sh`. It is not needed again unless you `rm -rf ./data` and recreate it.
    `up.sh` will create all required subdirectories and set their ownership automatically — the only manual step is the `chcon` label above.
- DNS configured: `admin-hyku.lib.wvu.edu` and `*.lib.wvu.edu` → VM IP
- SSL-terminating reverse proxy (Nginx or Traefik) in front, forwarding HTTP to port 3000
- Port 3000 not exposed publicly — only the proxy talks to it
- `git` access to this repo

> **RHEL vs Mac performance note:** The Solr healthcheck allows 600 s start period + 60 retries on the local compose. On the native x86_64 RHEL VM the JVM starts in ~30 s, so this window will never be hit. The longer window exists because developer ARM Macs run the `linux/amd64` Solr image under QEMU emulation, where JVM init is significantly slower. M4 Macs are particularly affected — QEMU emulation of the amd64 JVM on M4 can take 10+ minutes. A native arm64 Solr image is on Notch8's backlog; once available it will eliminate this delay entirely.

### Step 1: Clone with submodules

```bash
git clone --recurse-submodules https://github.com/wvulibraries/wvu_knapsack.git
cd wvu_knapsack
```

If already cloned without `--recurse-submodules`:
```bash
git submodule update --init --recursive
```

### Step 1b: Create the required knapsack branch

The bundler shim requires a local branch named `required_for_knapsack_instances` to exist. Create it once per clone:

```bash
git fetch prime
git checkout prime/required_for_knapsack_instances
git switch -c required_for_knapsack_instances
git checkout main   # return to main
```

(This is the same step documented in the [README quick start](README.md#2-create-the-required-knapsack-branch).)

### Step 2: Create env files

Five env files are required — one for the Rails app and one per infrastructure container:

```bash
cp .env.production.example .env.production
cp .env.db.example        .env.db
cp .env.redis.example     .env.redis
cp .env.solr.example      .env.solr
cp .env.fedora.example    .env.fedora
```

Each file is gitignored (`.env.*`). The `.example` counterparts are committed as templates.

> **Passwords must be kept in sync across files.** `POSTGRES_PASSWORD` in `.env.db` must also appear as `DB_PASSWORD` in `.env.production` and as `fcrepo.postgresql.password` inside `JAVA_OPTS` in `.env.fedora`. `REDIS_PASSWORD` in `.env.redis` must match the password embedded in `REDIS_URL` in `.env.production`.

> ⚠️ **Postgres password change requires a data wipe.** `POSTGRES_PASSWORD` is only read during **first initialization of an empty `./data/db`**. Once the cluster exists on disk, changing `.env.db` has no effect — the old password is baked into the cluster. Wipe `./data/db` (via the cleanup script, or `sudo rm -rf ./data/db`) before restarting so postgres reinitializes with the new credentials.

Edit `.env.production` with real values:

```bash
nano .env.production
```

Required changes from the example:

| Variable | File | VM Value |
|---|---|---|
| `SECRET_KEY_BASE` | `.env.production` | `openssl rand -hex 64` |
| `NEGATIVE_CAPTCHA_SECRET` | `.env.production` | `openssl rand -hex 32` |
| `DB_PASSWORD` | `.env.production` | Strong random password |
| `POSTGRES_PASSWORD` | `.env.db` | Same strong password as `DB_PASSWORD` |
| `JAVA_OPTS` (`fcrepo.postgresql.password`) | `.env.fedora` | Same strong password as `DB_PASSWORD` |
| `REDIS_PASSWORD` | `.env.redis` | Strong random password |
| `REDIS_URL` (password segment) | `.env.production` | Same strong password as `REDIS_PASSWORD` |
| `HYKU_ROOT_HOST` | `.env.production` | `lib.wvu.edu` |
| `HYKU_ADMIN_HOST` | `.env.production` | `admin-hyku.lib.wvu.edu` |
| `HYKU_DEFAULT_HOST` | `.env.production` | `%{tenant}-hyku.lib.wvu.edu` |
| `INITIAL_ADMIN_EMAIL` | `.env.production` | Real admin email |
| `INITIAL_ADMIN_PASSWORD` | `.env.production` | Strong password (change after first login) |
| `RAILS_SERVE_STATIC_FILES` | `.env.production` | `true` (unless Nginx serves `/assets` directly) |

**Leave unset / commented out on the VM:**
- `DISABLE_FORCE_SSL` — do not set this; the SSL proxy handles HTTPS
- `HYKU_EXTRA_HOSTS` — not needed; `*.lib.wvu.edu` is already in `host_authorization.rb`

Generate secrets:
```bash
openssl rand -hex 64   # paste into SECRET_KEY_BASE
openssl rand -hex 32   # paste into NEGATIVE_CAPTCHA_SECRET
```

### Step 3: Start the stack

```bash
sh up.sh
```

`up.sh` does: `git pull` → `git submodule update` → create data directories with correct ownership → `docker compose up -d`.

> **First run takes ~4 minutes.** The GHCR images are arm64-only and cannot run on the amd64 VM. `docker-compose.production.yml` uses `pull_policy: build` — images are built locally from the root Dockerfile on first run. Subsequent runs use Docker's layer cache and are much faster.

Watch startup:
```bash
# Check all infrastructure services (db, redis, fcrepo, fits, solr, zoo) are up
docker compose -f docker-compose.production.yml ps

docker compose -f docker-compose.production.yml logs -f initialize_app
docker compose -f docker-compose.production.yml logs -f web
```

Wait for `Listening on http://0.0.0.0:3000` in web logs.

### Step 4: Run one-time setup

```bash
docker compose -f docker-compose.production.yml exec web sh /app/samvera/scripts/setup.sh
```

Idempotent — safe to re-run on every update. This handles: asset precompilation, DB migrations, Solr configset, and optional first tenant creation.

To pre-create the first repository tenant instead of using the admin UI, add to `.env.production` before running setup:

```env
HYKU_FIRST_TENANT_NAME=wvu
HYKU_FIRST_TENANT_CNAME=wvu-hyku.lib.wvu.edu
```

> **Admin host is not a tenant.** `HYKU_ADMIN_HOST` routes to the superadmin interface — never try to create an `Account` record for it. Hyku reserves the admin cname and rejects it with "Domain names cname is reserved."

### Step 5: Verify the stack is up

```bash
docker compose -f docker-compose.production.yml ps
```

All services should show `Up`. Then visit `https://admin-hyku.lib.wvu.edu` — you should see the Hyku splash page.

### Step 6: Reverse proxy (Nginx example)

```nginx
server {
    listen 443 ssl http2;
    server_name admin-hyku.lib.wvu.edu *.lib.wvu.edu;

    ssl_certificate     /etc/ssl/certs/lib.wvu.edu.crt;
    ssl_certificate_key /etc/ssl/private/lib.wvu.edu.key;

    location / {
        proxy_pass         http://localhost:3000;
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto https;
        proxy_read_timeout 300s;
    }
}

server {
    listen 80;
    server_name admin-hyku.lib.wvu.edu *.lib.wvu.edu;
    return 301 https://$host$request_uri;
}
```

`X-Forwarded-Proto: https` is required — it tells Rails it's behind an SSL proxy so the `force_ssl` redirect loop doesn't occur.

### Stopping the stack

```bash
sh down.sh    # stops containers, data is preserved in ./data/
```

### Updating the application

```bash
# Pull latest code and restart — up.sh handles submodule update
sh down.sh
sh up.sh

# Run migrations, re-seed, and re-precompile assets if needed (all idempotent)
docker compose -f docker-compose.production.yml exec web sh /app/samvera/scripts/setup.sh
```

### Nuclear Option — complete wipe and rebuild

Use this when the stack is unrecoverable (e.g. postgres initialized with wrong password, Solr index corrupt, image layer cache poisoned).

> **Warning:** This permanently destroys the database, Solr index, Fedora objects, and all uploaded files. Coordinate with your team before running on a server that holds real data.

```bash
sh scripts/cleanup-prod.sh vm

# Then restart:
sh up.sh
docker compose -f docker-compose.production.yml logs -f initialize_app
docker compose -f docker-compose.production.yml exec web sh /app/samvera/scripts/setup.sh
```

**Postgres-only reset** (when only the DB is poisoned and you want to keep Solr/Fedora data):

```bash
sh down.sh
rm -rf ./data/db
sh up.sh
```

### Data persistence

All state is in `./data/` bind mounts. Back up this directory to preserve everything.

| Directory | Contents |
|---|---|
| `./data/db` | PostgreSQL database |
| `./data/solr` | Solr index + SolrCloud state |
| `./data/zoo` / `./data/zk` | ZooKeeper state |
| `./data/fcrepo` | Fedora repository objects |
| `./data/uploads` | User-uploaded files |
| `./data/assets` | Precompiled asset pipeline output |
| `./data/bundle` | Bundler gem cache (speeds up container restarts) |
| `./data/cache` | Rails tmp/cache |
| `./data/redis` | Redis persistence |
| `./data/logs/solr` | Solr logs |

---

## Configuration Reference

### Key files

| File | Purpose | Committed |
|---|---|---|
| `.env.production.example` | Template — web / worker / initialize_app vars | ✅ |
| `.env.db.example` | Template — postgres container (`POSTGRES_*`) | ✅ |
| `.env.redis.example` | Template — redis container (`REDIS_PASSWORD`) | ✅ |
| `.env.solr.example` | Template — solr container (`SOLR_ADMIN_*`, ZooKeeper) | ✅ |
| `.env.fedora.example` | Template — fcrepo container (`JAVA_OPTS` with DB creds) | ✅ |
| `.env.production` | Real values — web/worker/initialize_app | ❌ (gitignored) |
| `.env.db` | Real values — postgres container | ❌ (gitignored) |
| `.env.redis` | Real values — redis container | ❌ (gitignored) |
| `.env.solr` | Real values — solr container | ❌ (gitignored) |
| `.env.fedora` | Real values — fcrepo container | ❌ (gitignored) |
| `.env.development` | Stack Car local dev overrides | ✅ |
| `config/initializers/host_authorization.rb` | Adds `*.lib.wvu.edu` to Rails allowed hosts; reads `HYKU_EXTRA_HOSTS` | ✅ |
| `config/initializers/session_store_override.rb` | Drops `Secure` cookie flag when `DISABLE_FORCE_SSL=true` (required for CSRF over HTTP) | ✅ |
| `docker-compose.local.yml` | Local smoke test compose — pulls arm64 GHCR images, `pull_policy: always` | ✅ |
| `docker-compose.production.yml` | VM production compose — builds from root Dockerfile, `pull_policy: build` | ✅ |
| `startup-solr.sh` | Seeds `solr.xml` on fresh volume, starts Solr in SolrCloud mode (`-f -c -z`) | ✅ |
| `solr-setup/security.json` | Solr ZooKeeper auth (admin: `solr`/`SolrRocks`, app: `hydra`/`m0Nif7rNp3ZpkiKN52NA`) | ✅ |
| `scripts/setup.sh` | Idempotent DB + Solr + tenant setup | ✅ |
| `config/initializers/derivatives_im7_fix.rb` | Patches `Hyrax::FileSetDerivativesService` — only passes `layer: 0` to hydra-derivatives for TIFF/PDF sources; prevents MiniMagick IM7 src==dest corruption on JPEG/PNG ingest | ✅ |

### Solr collections

| Collection | Purpose |
|---|---|
| `hydra-production` | Main production index |
| `hydra-test` | Test suite index |

### Host routing logic

Hyku uses `HYKU_ADMIN_HOST`, `HYKU_DEFAULT_HOST`, and `HYKU_ROOT_HOST` to route requests:

- `admin-wvu-knapsack.*` → superadmin interface (no `Account` record needed)
- `{tenant}-wvu-knapsack.*` → tenant frontend (requires an `Account` record with matching cname)
- `HYKU_EXTRA_HOSTS` → additional hosts allowed through `HostAuthorization` (local testing only)

---

## Okta SAML Authentication

Hyku supports SAML SSO via the `omniauth-saml` gem. The configuration is **entirely database-driven** — there are no env vars for it. Each tenant (and the superadmin) can have its own identity provider record, created through the admin UI.

### Production admin URL

```
https://admin-hyku.lib.wvu.edu/identity_providers
```

> **Note:** The production superadmin interface is at `admin-hyku.lib.wvu.edu`. Use this URL for any Okta-related admin configuration on the live server.

### How to view or copy the working Okta configuration from the dev VM

SSH into the dev VM and run:

```bash
docker compose -f docker-compose.production.yml exec web bundle exec rails runner \
  "puts IdentityProvider.all.map { |p| { name: p.name, provider: p.provider, options: p.options }.inspect }"
```

This prints every identity provider row including the full Options JSON, which you can then re-enter in any other environment.

### Setting up a new identity provider

1. Log in at `https://admin-hyku.lib.wvu.edu` (production) or `http://admin-wvu-knapsack.lvh.me:3000` (local smoke test)
2. Go to **Dashboard → Configuration → Identity Providers → New**
3. Fill in:
   - **Name** — `WVU Okta` (or any label)
   - **Provider** — `saml`
   - **Options** — paste the JSON blob (see below)
4. **Save** — the Assertion Consumer Service (ACS) URL is shown on the edit page after saving

### Minimum Options JSON for WVU Okta

```json
{
  "idp_metadata_url": "https://wvu.okta.com/app/<app-id>/sso/saml/metadata",
  "sp_entity_id": "https://admin-hyku.lib.wvu.edu",
  "name_identifier_format": "urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress"
}
```

Replace `<app-id>` with the Okta application ID. The `idp_metadata_url` is the source of truth — Hyku auto-fetches the IDP certificate and SSO endpoint from it, so no other Okta-specific keys are required.

### ACS callback URL (register this in Okta)

After saving the identity provider record, the edit page shows the ACS URL(s) — one per tenant domain name. For production it will be:

```
https://admin-hyku.lib.wvu.edu/users/auth/saml/{record-id}/callback
```

This URL must be added to the Okta application's **Sign On → SAML Settings → Allowed Callback URLs** (or equivalent). Each environment (dev VM, local smoke test, production) needs its own entry if they point to different Okta apps, or all URLs can be added to a single Okta app.

### Local smoke test notes

For local testing over HTTP, the ACS URL will be:

```
http://admin-wvu-knapsack.lvh.me:3000/users/auth/saml/{record-id}/callback
```

Okta may refuse HTTP callback URLs depending on the app settings. Either configure a dev-only Okta app that allows HTTP, or test SAML only against the production/staging environment where HTTPS is available.

### SP metadata endpoint

Hyku exposes SP metadata at:

```
https://admin-hyku.lib.wvu.edu/users/auth/saml/{record-id}/metadata
```

Okta can be pointed at this URL for automatic SP configuration.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| 403 Blocked hosts | Host not in Rails allowed list | Verify `HYKU_ADMIN_HOST`/`HYKU_ROOT_HOST` match the request host; check `host_authorization.rb` |
| Login fails "change was rejected" (422) | CSRF: session cookie has `Secure` flag, not sent over HTTP | Set `DISABLE_FORCE_SSL=true` — triggers `session_store_override.rb` to drop Secure flag |
| Pages load with no CSS | Assets not precompiled or `RAILS_SERVE_STATIC_FILES` not set | Re-run `setup.sh` (step 1 is `assets:precompile`); ensure `RAILS_SERVE_STATIC_FILES=true` |
| Solr unhealthy / dependency failed to start | `linux/amd64` Solr image running under QEMU on Apple Silicon (M1/M2/M3/M4) — JVM init is slow | Wait longer — M4 can take 10+ minutes. Local compose allows up to ~16 min total (`start_period: 600s` + 60 × 10s retries). A native arm64 Solr image is on Notch8's backlog. |
| Solr not in SolrCloud mode | Wrong startup command | `startup-solr.sh` uses `solr start -f -c -z zoo:2181` — check logs |
| `solr.xml does not exist` | Fresh bind mount, no `solr.xml` | `startup-solr.sh` seeds it automatically from `/opt/solr/server/solr/solr.xml` |
| DB `ProtectedEnvironmentError` | `db:schema:load` blocked on existing DB | `setup.sh` detects table count and uses `db:migrate` — re-run setup |
| "Domain names cname is reserved" | Tried to create `Account` for admin host | Admin host is not a tenant — create repository tenants via admin UI |
| `restart` doesn't pick up new env | `restart` reuses cached container env | Use `docker compose up -d` to recreate containers and re-read `env_file` |
| File characterization fails / FITS errors | `fits` container not running | `docker compose ps` — check fits is `Up`; `docker compose logs fits` for errors |
| `ValkyrieCreateDerivativesJob` fails with `MiniMagick::Error: magick convert … No such file` | MiniMagick 4.x + IM7: passing `layer: 0` for JPEG/PNG triggers `Image.new` (no tempfile) → `Pathname#sub_ext` produces src == dest → IM7 truncates the file before reading it | Fixed by `config/initializers/derivatives_im7_fix.rb` (committed). Re-run derivatives on affected records: `bundle exec rails runner "FileSet.all.each {|fs| ValkyrieCreateDerivativesJob.perform_later(fs.id)}"` inside the worker container. |
| Tenant returns "not found" | DB seeded with wrong domain / APP_NAME | `docker compose down -v` to wipe volumes, then restart and re-setup |
| `FATAL: password authentication failed for user "postgres"` after changing `.env.db` | `POSTGRES_PASSWORD` is only read on first init of an empty `./data/db` — changing the env var has no effect once the cluster exists on disk | Wipe the cluster: `sudo rm -rf ./data/db` (or run the cleanup script), then restart. Postgres will reinitialize with the new password. |
| `Permission denied @ dir_s_mkdir - /usr/local/bundle` | `./data/bundle` created by root (fresh clone, or prior `--build` run wrote gems as root) | Handled automatically by the `fix_permissions` service in `docker-compose.local.yml`. On the VM, `up.sh` does `chown -R 1001:101 ./data/bundle` before compose up. Manual fix: `sudo chmod -R 777 ./data/bundle` then restart. |
| Bundle install slow on every start | Gems reinstall into container-local paths | Expected on first run; `./data/bundle` is cached so subsequent restarts are fast |
| `up.sc.local.sh` takes a long time | `--no-cache` rebuild | Normal — use `sc up -d` directly when you don't need a clean rebuild |

---

## Quick Reference

### Stack Car (local dev)

```bash
sh up.sc.local.sh                 # clean rebuild + start
sh down.sc.local.sh               # stop
sc logs web -f                    # tail web logs
sc sh                             # shell into web container
sc exec bundle exec rails console # Rails console
sc exec bundle exec rspec spec/   # run specs
sc proxy up                       # start Traefik proxy
```

### Local production smoke test (Mac arm64)

```bash
sh up.prod.local.sh
sh down.prod.local.sh
docker compose -f docker-compose.local.yml ps
docker compose -f docker-compose.local.yml logs -f web
docker compose -f docker-compose.local.yml exec web sh /app/samvera/scripts/setup.sh
docker compose -f docker-compose.local.yml exec web bundle exec rails console
```

### VM production deployment

```bash
sh up.sh                          # git pull + build + start
sh down.sh                        # stop

# Manual equivalents:
docker compose -f docker-compose.production.yml up -d
docker compose -f docker-compose.production.yml down
docker compose -f docker-compose.production.yml ps
docker compose -f docker-compose.production.yml logs -f web
docker compose -f docker-compose.production.yml exec web sh /app/samvera/scripts/setup.sh
docker compose -f docker-compose.production.yml exec web bundle exec rails console
```

### Nuclear Option

```bash
# Stack Car dev (named volumes)
sh scripts/cleanup-dev.sh

# Local smoke test (bind mounts in ./data/)
sh scripts/cleanup-prod.sh

# VM production (bind mounts in ./data/)
sh scripts/cleanup-prod.sh vm
```

**Postgres-only reset (VM — keep Solr/Fedora data):**
```bash
sh down.sh && rm -rf ./data/db && sh up.sh
```

---

## SSO/Identity Provider Configuration Reference

For up-to-date instructions on enabling and configuring SSO (SAML, Okta, etc.) in Hyku, see the official documentation:

- [Hyku Identity Provider: Single Sign-On (SSO) Documentation](https://samvera.atlassian.net/wiki/spaces/hyku/pages/3570663437/Identity+Provider+Single+Sign-On+SSO)

This resource covers:
- Enabling the Identity Provider feature per tenant (Settings → Features)
- Creating and editing Identity Provider records in the admin UI
- Required and optional JSON fields for SAML/Okta
- Attribute mapping, ACS URLs, and troubleshooting tips

Always refer to this documentation for the latest best practices and UI-driven setup steps.
