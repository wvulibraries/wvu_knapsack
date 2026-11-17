# Testing Best Practices: Fresh Snapshots Between Test Cycles

**Category:** Operations  
**Date Created:** 2026-11-17

## Snapshot Purpose

WVU keeps only **one snapshot at a time**. The workflow is:

1. Request a snapshot of the current stable state
2. Do work on top of it
3. If the update fails, request a restore to that single snapshot

There is no comparison between multiple snapshots — just one rollback point.

## Snapshot Checklist

Before requesting a snapshot for major version testing (7.2.0, 7.3, etc.):

- [ ] Running version (e.g., 7.1.3) is verified stable
- [ ] All gem versions correct (Gemfile.lock or constraints applied)
- [ ] Records displaying in search (data + code both working)
- [ ] Facet counts loading correctly
- [ ] Provide a clear label: e.g., `v7.1.3-clean-baseline`

## Requesting a Snapshot

WVU does not provide direct snapshot CLI access. Instead, request snapshots through the appropriate channel (hykudev admin or infrastructure team).

### How to Request a Snapshot

1. **Confirm the baseline is stable** before requesting (records displaying, facets loading)
2. **Provide a clear label** so it can be restored later
3. **Document the request** in agent-tasks so the next session knows what was captured

### Restoring from Snapshot

When an update fails badly:
1. Request restoration of the labeled snapshot
2. Verify the restored state matches expectations
3. Document any differences from the baseline

## When to Snapshot

- Before any major version upgrade test
- After confirming a stable baseline
- Before attempting fixes that may break things further
