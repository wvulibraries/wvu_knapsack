# Testing Best Practices: Fresh Snapshots Between Test Cycles

**Category:** Operations  
**Date Created:** 2026-11-17

## Snapshot Purpose

- **Checkpoint:** Known-good baseline to compare against
- **Insurance:** Can revert failed test without full rebuild
- **Comparison:** Multiple snapshots let you compare "working" vs "broken"

## Snapshot Checklist

Before major version testing (7.2.0, 7.3, etc.):

- [ ] Running version (e.g., 7.1.3) is verified stable
- [ ] All gem versions correct (Gemfile.lock or constraints applied)
- [ ] Records displaying in search (data + code both working)
- [ ] Facet counts loading correctly
- [ ] Take snapshot with clear label: `2026-11-05-v7.1.3-clean-baseline`

## Using Snapshots

```bash
# Before upgrading
snapshot create "v7.1.3-clean-baseline"

# Test upgrade (7.2.0 branch)
# If it fails badly
snapshot restore "v7.1.3-clean-baseline"

# To compare two versions
snapshot list
# Apply diff: git diff main feature/hyku-v7.2.0-upgrade
```

## When to Snapshot

- Before any major version upgrade test
- After confirming a stable baseline
- Before attempting fixes that may break things further
- When switching between test branches
