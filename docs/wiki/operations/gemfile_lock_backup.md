# Gemfile.lock Backup & Recovery

**Category:** Operations  
**Date Created:** 2026-11-17  
**Status:** Critical Procedure  
**Last Updated:** 2026-11-17

## The Issue

The `hyrax-webapp/Gemfile.lock` file is in a **git submodule** (pointing to upstream samvera/hyrax). However:

- Local development requires a **specific, pinned version** of dependencies
- Simply checking out the submodule doesn't guarantee the right Gemfile.lock state
- **DevOps had to manually copy Gemfile.lock from production VMs** to get hykudev and local environments working
- Removing or regenerating this Gemfile.lock causes bundle install failures and incompatible gem versions

## Why This Happens

- The submodule SHA points to a specific Hyku version
- That version's Gemfile.lock may have drifted from what's in the git tree
- Running `bundle install` or `bundle update` locally can generate incompatible versions
- **This is why we don't modify the submodule** — to preserve this exact state

## Backup Location

**Current backup:** `/Users/tam0013/.copilot/session-state/4e01e37b-32bd-427f-b787-c7a4cd5ff972/files/Gemfile.lock.backup`

**Checksum:** (verify after restore)

## Recovery Procedure

If Gemfile.lock becomes corrupted or missing:

```bash
cd /Users/tam0013/Documents/git/wvu_knapsack/hyrax-webapp

# Check if Gemfile.lock is missing or broken
ls -la Gemfile.lock

# Restore from backup (if available)
cp /Users/tam0013/.copilot/session-state/4e01e37b-32bd-427f-b787-c7a4cd5ff972/files/Gemfile.lock.backup Gemfile.lock

# Verify it matches production
md5sum Gemfile.lock
# Compare with output from: md5sum /path/to/prod/hyrax-webapp/Gemfile.lock

# DO NOT commit this file (it's in .gitignore for good reason)
git status  # should show no changes
```

## Never Do This

- ❌ Run `bundle update` in hyrax-webapp directory
- ❌ Delete or move Gemfile.lock
- ❌ Commit changes to Gemfile.lock locally
- ❌ Copy a different version from another dev's machine

## Related Procedures

- [Submodule Rule](./submodule_rule.md) — Never modify hyrax-webapp
- [Gem Version Drift](./gem_version_drift.md) — Why versions matter
- [Local Deployment](./local_deployment.md) — Full setup instructions
