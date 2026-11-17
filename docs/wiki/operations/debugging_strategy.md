# Local-First Debugging Strategy

**Category:** Operations  
**Date Created:** 2026-11-17  
**Related:** [Gem Version Drift](./gem_version_drift.md)

## The Pattern That Failed

1. ❌ Upgrade hykudev to new version
2. ❌ See error, try to fix on hykudev VM
3. ❌ Spend hours debugging in production environment
4. ❌ Cannot easily revert, cannot compare with baseline

## The Pattern That Works

1. ✅ Upgrade locally with Stack Car first
2. ✅ Verify it works locally (or find the issue quickly in a controlled environment)
3. ✅ If it works locally but fails on VM → **infrastructure issue** (docker config, mount points, env vars)
4. ✅ If it fails locally → **code issue** (fix, test locally, then deploy to VM)

## Decision Tree

```
Local test fails?
├── Yes → Code issue
│         → Fix in branch, test locally, merge to hykudev
│
└── No (local works) → VM only fails?
                          ├── Yes → Infrastructure issue
                          │         → Compare docker config (prod vs local)
                          │         → Check env vars (SOLR_COLLECTION_NAME, etc.)
                          │         → Verify Solr collections exist and are accessible
                          │
                          └── No (both work but broken) → Data/config issue
                                                         → Check data integrity
                                                         → Review configuration drift
```

## Why This Matters

- **Local testing is fast:** No SSH delays, easy to restart containers, easy to inspect files
- **VM is production:** hykudev is a production environment with persistent data; mistakes are costly
- **Reference baseline:** Use local setup as "known good" for comparison
- **Isolation:** Clear separation between code issues and infrastructure issues

## Applying to Upgrade Testing

When testing a Hyku version upgrade (e.g., 7.2.0):

1. Test locally first: `cd /path/to/knapsack && docker compose up -d --build` on the upgrade branch
2. If local search works but VM search fails → investigate hykudev config, not code
3. If local search fails → code issue; fix in branch, test locally, then merge
