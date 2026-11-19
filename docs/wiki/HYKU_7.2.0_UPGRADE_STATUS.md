# Hyku 7.2.0 Upgrade Status — November 19, 2026

## Current State

### ✅ Completed
- **Bulkrax 10.0.1 override** via `bundler.d/bulkrax.rb` (verified in production logs)
- **Production upgrade documentation** in [HYKU_BUILD_GUIDE.md](/HYKU_BUILD_GUIDE.md) Section 4
- **field_config.limit.zero? compatibility fix** applied (commit fb6b56a)
- **Hykudev services** up and running on 7.2.0
- **Fresh local dev environment tested**: 5-record import, full upgrade path, records display correctly

### ⚠️ Current Issue — Blocking Production Upgrade
- **Search results not displaying on hykudev (production mode)**
  - Facets showing counts (Solr data intact) ✅
  - Records don't render in results view ❌
  - **Analysis**: Fresh local dev works fine → indicates production data or Solr state incompatibility
  - **Requires investigation**: Solr re-indexing, field format compatibility, or display template regression

## Testing Results

| Environment | Status | Records Display? | Notes |
|-------------|--------|------------------|-------|
| Local dev (Stack Car) | ✅ Working | ✅ Yes | 5 test records, full upgrade path verified |
| Hykudev (Production mode) | ⚠️ Partial | ❌ No | Services healthy, facets work, records missing |
| Production (demo-hyku) | ✅ Working | ✅ Yes | Baseline for comparison |

## Known Issues & Blockers

### 1. field_config.limit.zero? Error (FIXED ✅)

**Root Cause:**
- Old production data had `field_config.limit = true` (boolean)
- Hyku 7.2.0 / Blacklight 7.43.x code expects `limit` to be `nil` or integer
- Code calls `.zero?` on the limit value, which fails for booleans

**Fix Applied:**
- Commit fb6b56a: Changes `field_config.limit.zero?` → `field_config.limit == 0`
- Safe comparison handles boolean, nil, and integer
- Applied to `config/initializers/catalog_controller_decorator.rb` line 131

**Status:**
- ✅ Pushed to origin/feature/hyku-v7.2.0-upgrade
- ✅ Hykudev pulled and rebuilt successfully
- ✅ No more initialization errors

---

### 2. Search Results Not Displaying (INVESTIGATING 🔍)

**Symptom:**
- Facet sidebar shows counts (Folk Music: 4, Creator: multiple)
- Main search results area is empty (no record cards)
- Compare: locally shows full record cards with thumbnails, hykudev shows nothing

**Analysis:**
- **Code is correct** (local fresh dev works fine)
- **Data exists** (facet counts prove Solr has records)
- **Likely issue**: Production data format incompatible with 7.2.0 display template, or Solr wasn't re-indexed during upgrade

**Next Investigation Steps:**
1. Check if Solr needs re-indexing on hykudev
2. Compare Solr field schemas: local vs hykudev
3. Review browser console for JS errors
4. Check server logs for template errors

---

## Technical Details

### Bulkrax 10.0.1 Override Pattern
File: `bundler.d/bulkrax.rb`
```ruby
override_gem 'bulkrax', '10.0.1'
```
- Uses bundler-inject's `override_gem` mechanism
- Forces knapsack-level bulkrax version regardless of submodule spec
- Verified working: logs show "Installing bulkrax 10.0.1" despite hyrax-webapp submodule shipping 10.0.0

### Production Upgrade Gotchas (Documented)
See [HYKU_BUILD_GUIDE.md](/HYKU_BUILD_GUIDE.md) Section 4 "Upgrading to a New Hyku Version":

1. **Docker Image Caching (Production-Specific)**
   - Production uses `image: ghcr.io/.../web:${TAG:-latest}` with `pull_policy: build`
   - Caches aggressively; switching branches doesn't trigger rebuild
   - **Fix**: `docker compose -f docker-compose.production.yml build --no-cache`

2. **Submodule Sync Requirement**
   - Branch submodule reference must be pushed to origin first
   - Production VM can't fetch commits that haven't been pushed
   - **Fix**: On VM: `git fetch origin && git submodule update --init --recursive`

3. **Gemfile.lock Permission Chain**
   - If file doesn't exist, bundler fails with "can't write to Gemfile.lock"
   - Must be created fresh with correct ownership/permissions
   - **Fix**: 
     ```bash
     rm -f hyrax-webapp/Gemfile.lock
     touch hyrax-webapp/Gemfile.lock
     chown 1001:101 hyrax-webapp/Gemfile.lock
     chmod 644 hyrax-webapp/Gemfile.lock
     ```
   - Container user: UID 1001, GID 101 (nagios:101 on VM)

---

## Files Modified

- **bundler.d/bulkrax.rb** — Forces bulkrax 10.0.1 at knapsack level
- **config/initializers/catalog_controller_decorator.rb** — Safe facet config comparisons (line 131: `== 0` not `.zero?`)
- **HYKU_BUILD_GUIDE.md** Section 4 — Production upgrade procedures, troubleshooting table
- **feature/hyku-v7.2.0-upgrade** branch — 4 commits ahead of origin:
  - 82d803d (HEAD) docs: document critical production upgrade steps
  - fb6b56a fix: Handle boolean limit values in facet configuration
  - 399d4d8 fix: Restore YAML-driven facet configuration
  - 2bbf2f1 fix(facets): Apply working facet limiter

---

## Next Steps

### Immediate (Blocking)
1. **Investigate search display issue** on hykudev
   - Check Solr re-indexing status
   - Compare field schemas: local vs production
   - Review browser/server logs for errors
   - **Goal**: Fix or document the root cause

### After Display Issue Resolved
2. **Verify upgrade path** on hykudev
   - Test metadata separator fix (original Sarah research task)
   - Full smoke test of all major features
   - Document any additional gotchas

3. **Update this wiki** with:
   - Root cause of display issue
   - Solution applied
   - Final verification checklist
   - Upgrade readiness status for production

---

## Related Tasks & Documentation

- **Agent Tasks**: `/Users/tam0013/Documents/git/agent-tasks/projects/wvu_knapsack/tasks/active/2026-11-05-HIGH-BUG-HYKU-7.2.0-LOCAL-TESTING-PLAN.md`
- **Build Guide**: [HYKU_BUILD_GUIDE.md](/HYKU_BUILD_GUIDE.md)
- **Session Checkpoint**: `007-hyku-7-2-0-upgrade-hykudev-in-progress.md` (in session state)
- **Grok Session**: `grok-session.md` (debugging logs)

---

**Last Updated**: November 19, 2026 1:40 PM
**Status**: 🟡 In Progress — Blocking issue under investigation
