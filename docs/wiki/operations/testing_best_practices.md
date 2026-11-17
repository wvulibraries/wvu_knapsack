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

## Requesting Snapshots

WVU does not provide direct snapshot CLI access. Instead, request snapshots through the appropriate channel (hykudev admin or infrastructure team).

### How to Request a Snapshot

1. **Identify what needs checkpointing:** running version, gem versions, data state
2. **Provide a clear label:** e.g., `v7.1.3-clean-baseline`
3. **Confirm the baseline is stable** before requesting (records displaying, facets loading)
4. **Document the request** in agent-tasks so the next session knows what was captured

### Restoring from Snapshot

When a test fails badly:
1. Request restoration of the labeled snapshot
2. Verify the restored state matches expectations
3. Document any differences from the baseline

## When to Snapshot

- Before any major version upgrade test
- After confirming a stable baseline
- Before attempting fixes that may break things further
- When switching between test branches
