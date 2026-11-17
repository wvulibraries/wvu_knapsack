# Root Cause Analysis: Why Gemfile.lock Copy from Prod VM Was Needed

**Category:** Diagnosis  
**Date:** 2026-11-17  
**Status:** Resolved  
**Key Finding:** The knapsack Gemfile.lock was deleted but Docker still tries to copy it

---

## The Problem

When you locally built Knapsack after the 7.2 upgrade testing:

1. **Docker does `COPY Gemfile* /app/samvera/`** (line 32 of Dockerfile)
2. **Knapsack's Gemfile.lock doesn't exist** (deleted Aug 29, 2025 in commit `6c083c2`)
3. **Bundle install runs with NO lockfile** → dependency resolution from scratch
4. **Fresh resolution picks incompatible gem versions** that don't work together
5. **Build fails locally, but works on prod VMs** because prod has the prod-pinned Gemfile.lock

## Why Prod VMs Work

- Production **does have** a valid Gemfile.lock that was pinned to work with the submodule's specific Hyku version
- When you copied it over, Docker used the **prod-tested lockfile**, ensuring compatible versions
- This is why DevOps had to do the same on hykudev — without it, `bundle install` resolves differently

## Why This Architecture Is Problematic

```
knapsack/Gemfile          ← Minimal (just pulls hyrax-webapp/Gemfile via eval)
knapsack/Gemfile.lock     ← DELETED (not tracked)
                            ↓
hyrax-webapp/Gemfile      ← Real dependencies
hyrax-webapp/Gemfile.lock ← EXISTS but in SUBMODULE (not committed to knapsack)
                            ↓
Dockerfile line 32: COPY Gemfile* /app/samvera/
                    ↑
              Copies only knapsack/Gemfile (no .lock!)
              Submodule files are NOT copied at this stage
```

## Why It Worked Before

- Commit `01c95c1` ("Revert Updating knapsack's Gemfile.lock") shows Gemfile.lock WAS tracked
- Commit `6c083c2` ("Delete Gemfile.lock") removed it, assuming Bundler would resolve cleanly
- This assumption broke with the 7.2 upgrade because hyrax-webapp has tighter constraints

## Why We Can't Just Fix It By Adding Gemfile.lock Back

- **Knapsack's Gemfile** is minimal — it's essentially a passthrough to the submodule's real Gemfile via `eval()`
- Knapsack's Gemfile.lock should **always** match the submodule's Gemfile.lock (they're the same dependencies)
- Tracking both is redundant if the submodule's .lock is pinned
- **But** Docker copies **before** the submodule is available, creating the gap

## The Real Fix (Option 1: Recommended)

**Stop deleting knapsack's Gemfile.lock. Keep it synced with hyrax-webapp's:**

1. When updating the submodule SHA, also update knapsack's Gemfile.lock
2. Docker copies it at the right time (before source mount)
3. `bundle install` uses the pinned lockfile → reproducible builds everywhere

```bash
# After updating hyrax-webapp submodule
cp hyrax-webapp/Gemfile.lock Gemfile.lock
git add Gemfile.lock
git commit -m "chore: sync Gemfile.lock with submodule update (hyrax-webapp SHA: ...)"
```

## Alternative (Option 2: Docker-Level Fix)

**Modify Dockerfile to copy submodule files earlier:**

```dockerfile
# Copy submodule first (before generic "COPY . /app/samvera")
COPY --chown=1001:101 hyrax-webapp/Gemfile* /app/samvera/hyrax-webapp/

# Then copy knapsack root
COPY --chown=1001:101 Gemfile* /app/samvera/

# Bundle install now has access to hyrax-webapp/Gemfile.lock
RUN bundle install --jobs "$(nproc)"
```

However, this risks copying unwanted submodule runtime files. **Option 1 is cleaner.**

## Why We're Using the Prod Copy Now (Workaround)

- Production has a **known-working Gemfile.lock** from successful deploys
- Copying it guarantees the same versions local builds use
- It's not ideal, but it's reliable until we implement a proper fix
- **This backup is essential as insurance** while the root cause remains

## The Real Issue: Why Does Fresh Bundle Install Differ Locally vs Prod?

Since your team intentionally **discards Gemfile.lock and rebuilds on submodule updates**, the issue isn't the lockfile deletion itself. The issue is:

**When Docker does a fresh `bundle install` without a lockfile:**
- ✅ Prod VM resolves to compatible gems → build succeeds
- ❌ Local machine resolves to incompatible gems → build fails

This suggests environmental differences:

1. **Different Docker base images?** Check `FROM ghcr.io/samvera/hyrax/hyrax-base:` version
2. **Different Ruby versions in base image?** Even minor versions affect gem resolution
3. **Different gem source availability?** Network, gem server mirrors, cached gems
4. **Different Bundler versions?** Bundler resolution algorithm changed in v2.x
5. **Build environment state?** Stale Docker volumes, conflicting cached gems

## Diagnosing the Real Build Failure

To understand what gems conflict locally:

```bash
# On your local machine, trigger a full rebuild
docker compose down --volumes
docker system prune -a  # Remove all dangling images/volumes

# Rebuild and capture the error
docker compose build --no-cache 2>&1 | tee build.log

# Search for the actual bundle error
grep -A 20 "bundle install" build.log
grep -i "conflict\|incompatible\|version" build.log
```

**Key question:** When you copied Gemfile.lock from prod, did the **exact same gem versions** resolve locally without conflict? If so, that tells us what the resolution algorithm is picking differently.

## Next Steps

1. **Don't remove the prod Gemfile.lock backup** — it's your safety net
2. **Document the actual bundle error** when fresh resolution fails locally
3. **Compare environments:** Check if Dockerfile base image, Ruby version, or Bundler version differs between local and prod
4. **Test hypothesis:** Force a specific Bundler version locally and see if resolution changes
5. **Consider:** If prod resolves cleanly each time but local doesn't, the issue is local build environment, not policy

## References

- Deleted in: `6c083c2` ("Delete Gemfile.lock") — Aug 29, 2025
- Dockerfile line 32: `COPY Gemfile* /app/samvera/`
- Knapsack Gemfile: Uses `eval()` to load hyrax-webapp/Gemfile dynamically
- Backup location: `/Users/tam0013/.copilot/session-state/4e01e37b-32bd-427f-b787-c7a4cd5ff972/files/Gemfile.lock.backup`
