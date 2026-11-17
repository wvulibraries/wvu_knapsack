# Critical Rule: Never Modify Hyrax-Webapp Submodule Locally

**Category:** Operations  
**Date Created:** 2026-11-17  
**Status:** Standing Rule

## The Rule

**NEVER modify the `hyrax-webapp` submodule locally.** This is a hard rule that must be followed without exception.

### What This Means

- ❌ Do NOT edit `hyrax-webapp/Gemfile.lock` locally
- ❌ Do NOT change `hyrax-webapp/` file structure
- ❌ Do NOT commit changes to the submodule
- ✅ DO reset any changes: `git checkout hyrax-webapp`

### Why

- `hyrax-webapp` is the **official upstream Hyku repository** (samvera/hyrax)
- It's tracked as a git submodule pointing to a specific SHA
- Local changes create "dirty" submodule state that breaks reproducibility
- Other developers pulling your branch will get unpredictable behavior
- DevOps cannot reliably deploy if the submodule is modified

## What To Do If Hyku Needs Fixing

**Use proper Samvera procedures:**

1. **Identify the bug** in hyrax-webapp code
2. **Create a branch** in the **upstream Hyku repository** (samvera/hyrax on GitHub)
3. **Submit a PR** to samvera/hyrax with the fix
4. **Wait for merge** to upstream
5. **Update the submodule SHA** in knapsack to point to the fixed version
6. **Submit PR** to wvu_knapsack with the submodule update

This ensures the fix benefits the entire Samvera community and is properly maintained.

## Resetting a Dirty Submodule

If you accidentally modified the submodule:

```bash
cd /Users/tam0013/Documents/git/wvu_knapsack
git checkout hyrax-webapp
git status  # should show no changes
```

## References

- [Gem Version Drift](./gem_version_drift.md) — Gemfile.lock is in hyrax-webapp, don't modify it
- [Local-First Debugging](./debugging_strategy.md) — Debug in knapsack app, not in submodule
