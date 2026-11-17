# Gemfile.lock Backup & Recovery

**Category:** Operations  
**Date Created:** 2026-11-17  
**Status:** Local Cache for Quick Recovery  
**Last Updated:** 2026-11-17

## The Purpose

This backup allows you to **quickly restore a known-working Gemfile.lock from production** without needing to download it again from the prod VM.

It's a **safety cache**, not a permanent replacement for the team's rebuild-on-update policy.

## Why We Need It

- When you rebuild on submodule updates (intentional policy), fresh `bundle install` can resolve incompatibly on local machines
- If local builds fail due to gem conflicts, you can quickly restore the prod-tested version without re-downloading
- This keeps you unblocked while maintaining the policy of discarding old lockfiles on updates

## Backup Location

**Current backup:** `/Users/tam0013/.copilot/session-state/4e01e37b-32bd-427f-b787-c7a4cd5ff972/files/Gemfile.lock.backup`

**Checksum:** (verify after restore)

## Recovery Procedure

If Gemfile.lock becomes corrupted or missing **and local builds fail with gem conflicts**:

```bash
cd /Users/tam0013/Documents/git/wvu_knapsack/hyrax-webapp

# Check if Gemfile.lock is missing or broken
ls -la Gemfile.lock

# Restore from cached backup
cp /Users/tam0013/.copilot/session-state/4e01e37b-32bd-427f-b787-c7a4cd5ff972/files/Gemfile.lock.backup Gemfile.lock

# Verify it matches production's version
md5sum Gemfile.lock
# Should output: 7b4ed53d782f8f0103bcd2537d0d6052

# Rebuild locally
docker compose down --volumes
docker compose build --no-cache
sh up.sc.local.sh
```

## Important Notes

- **Only use this if:**
  - Local docker build fails with gem conflicts
  - You can't re-download from the prod VM
  - You need to get building again quickly

- **Don't commit this Gemfile.lock** to git — the team policy is to rebuild on submodule updates
- **After production VMs are updated** with new submodule versions, download a fresh backup to replace this one
- **Keep the prod VM as the source of truth** — this is just a local cache

## Related Procedures

- [Submodule Rule](./submodule_rule.md) — Never modify hyrax-webapp
- [Gem Version Drift](./gem_version_drift.md) — Why versions matter
- [Local Deployment](./local_deployment.md) — Full setup instructions
