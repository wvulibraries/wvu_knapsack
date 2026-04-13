# TASK: Add cleanup-dev.sh to remove Solr volume from correct compose project scope
**Status**: BACKLOG
**Priority**: MEDIUM
**Type**: bug-fix
**Created**: 2026-04-06
**Last Updated**: 2026-04-06

---

## Agent Assignment

**Assigned To**: GPT-4.1 0x
**Why This Agent**: Shell script edit — single file, explicit fix provided
**Supervision Level**: 🔴 Watched carefully

---

## Context

`scripts/cleanup-dev.sh` runs `docker compose down --rmi local -v --remove-orphans` to nuke the dev stack. However, the project has two `docker-compose.yml` files declaring a `solr:` named volume:
- `docker-compose.yml` (root)
- `hyrax-webapp/docker-compose.yml`

Docker may scope the volume removal to only one compose project, leaving Solr data behind. This is why ghost Solr records survived after running cleanup. The fix is to ensure Solr data is explicitly cleared.

---

## Problem Statement

**Current behavior**: After `sh scripts/cleanup-dev.sh`, Solr volume data persists in some cases — ghost records survive into the next stack start.

**Expected behavior**: Cleanup fully wipes all named volumes including Solr, leaving a truly fresh state on next `sh up.sc.local.sh`.

---

## Files Involved

### Primary Files — you will edit these
| File | Purpose |
|---|---|
| `scripts/cleanup-dev.sh` | Dev stack nuclear option |

---

## Implementation Steps

### Step 1 — Check current script
Read `scripts/cleanup-dev.sh` — it currently runs:
```bash
docker compose down --rmi local -v --remove-orphans 2>/dev/null || true
```

### Step 2 — Add explicit Solr data volume removal
After the `docker compose down` line, add:
```bash
# Explicitly remove solr volume which may persist due to dual compose file scoping
docker volume rm wvu_knapsack_solr 2>/dev/null || true
docker volume rm hyrax-webapp_solr 2>/dev/null || true
# Remove any solr volume matching project name pattern
docker volume ls --format '{{.Name}}' | grep solr | xargs -r docker volume rm 2>/dev/null || true
```

### Step 3 — Verify volume names
First check what volumes actually exist after a stack run:
```bash
docker volume ls | grep -i solr
```
Use the actual volume names in the cleanup script.

---

## Acceptance Criteria
- [ ] After `sh scripts/cleanup-dev.sh`, `docker volume ls | grep solr` returns nothing
- [ ] Fresh `sh up.sc.local.sh` starts with empty Solr
- [ ] Script still exits cleanly even when volumes don't exist (all `|| true`)

---

## Stop Conditions — escalate to user immediately if:
- Volume names are different from expected — inspect and update the script

---

## Dependencies
**Blocked by**: none
**Blocks**: `2026-04-06-LOW-DATA-CLEANUP-GHOST-SOLR-RECORDS.md` (prevents future ghosts)
**Related tasks**: none

---

## Completion Report
*To be filled in by implementing agent*
