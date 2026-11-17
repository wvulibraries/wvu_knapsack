# Local Stack Car Environment Mismatch After Upgrade Testing

**Category:** Troubleshooting  
**Date Created:** 2026-11-17  
**Status:** Ongoing — requires full environment reset

## Symptom

After major version upgrade testing (e.g., 7.2.0, 7.2.1), local Stack Car environment diverges from production hykudev:
- Error: `ActionView::MissingTemplate` for partials that exist in production
- Same SHA and Gemfile.lock as production, but local still fails
- Errors do not occur on hykudev VM or demo (both prod)

## Root Cause

Local Stack Car accumulates state during upgrade testing cycle:
1. Checkout new version branch → Gemfile.lock changes
2. Reset to old version → Docker container state remains
3. Copy submodule Gemfile.lock from prod → helps but doesn't fully resolve
4. Stale Docker volumes and build cache → views/gems not properly resolved

## Why It Happens

- **Docker volumes persist** even after `docker compose down`
- **Bundle cache** may have conflicting gem versions
- **View file resolution** differs between development and production mode
- **Submodule state** is tricky — copying Gemfile.lock isn't enough to fully reset

## Solution: Full Environment Reset

When local Stack Car diverges from production after upgrade testing:

```bash
cd /Users/tam0013/Documents/git/wvu_knapsack

# Step 1: Destroy everything
docker compose down --volumes --remove-orphans

# Step 2: Reset to production state
git checkout main
git submodule update --init --recursive

# Step 3: Ensure submodule Gemfile.lock matches production
# (copy from hykudev if needed, or pull latest main)

# Step 4: Verify no local modifications
git status  # should be clean
cd hyrax-webapp && git status  # should be clean
cd ..

# Step 5: Rebuild clean
docker compose build --no-cache
sh up.sc.local.sh
```

## Prevention

- **Always test 7.2+ upgrades on hykudev first**, then confirm main works locally before heavy local testing
- **Never modify submodule Gemfile.lock locally** — always reset it to committed state
- **Use snapshots**: Request VM snapshot before upgrade testing, then restore if things break
- **Document divergence**: If local diverges, document the steps taken and what was different

## References

- [Gem Version Drift](../operations/gem_version_drift.md) — why Gemfile.lock matters
- [Testing Best Practices](../operations/testing_best_practices.md) — snapshot workflow
- [Local-First Debugging](../operations/debugging_strategy.md) — when to use local vs VM
