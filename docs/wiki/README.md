# WVU Libraries Knapsack — Wiki

This folder is the **live wiki** for the WVU Libraries Knapsack project — a Hyku digital repository for institutional archives.

---

## Navigation by category

| Directory | Description |
|-----------|-------------|
| [**operations/**](operations/) | Setup, deployment, and developer guides (local dev, VM deployment, smoke testing) |
| [**infrastructure/**](infrastructure/) | Storage architecture, data persistence, backup/restore procedures |
| [**troubleshooting/**](troubleshooting/) | Known issues, bug investigations, and fix documentation (configuration and operational) |

---

## Operations

| Page | Notes |
|------|-------|
| [Hyku Build Guide — Setup, local testing, VM deployment](operations/hyku_build_guide.md) | Complete developer and DevOps guide: Stack Car dev, production smoke test, VM deployment |
| [Gem Version Drift in Hyku Builds](operations/gem_version_drift.md) | Why Gemfile.lock must be committed; how to diagnose and prevent dependency mismatches |
| [Local-First Debugging Strategy](operations/debugging_strategy.md) | Decision tree: test locally with Stack Car first, then VM only for final validation |
| [Testing Best Practices — Fresh Snapshots](operations/testing_best_practices.md) | Snapshot checklist before major version upgrades; when and how to checkpoint |

## Infrastructure

| Page | Notes |
|------|-------|
| [Storage Architecture — data persistence, backup/restore](infrastructure/storage_architecture.md) | Where each type of data lives, storage mount criticality, backup strategy, troubleshooting |

## Troubleshooting

| Page | Notes |
|------|-------|
| [Bulkrax metadata separator splits on colons AND semicolons](troubleshooting/bulkrax/bulkrax_metadata_separator_issue.md) | CSV imports split on `[:;|]` instead of `;` only — config fix, no code change needed |
| [Solr Collection Mismatch Architecture](troubleshooting/solr_collection_mismatch.md) | Indexing writes to one collection, search reads from another — how to diagnose and confirm |

---

## Wiki Standards & Conventions

All files in `docs/wiki/` follow these rules. New pages must comply:

1. **File names:** strict `lower_snake_case` — `file_name.md`. No Title-Case, no kebab-case.
2. **Links use explicit relative paths** with accurate `../` depth matching the source file's subdirectory level.
3. **All incoming links must resolve against tracked files** (`git ls-files`). Before merging, verify every new relative path exists in `git ls-files docs/wiki/`.
4. **Anchor links:** use lowercase with hyphens (`#section-title`) matching the first `#` heading exactly.
5. **No links out of the wiki.** `docs/wiki/` is the source of truth. Older documentation is retired reference and harvest material.
6. **Labels.** The page banner describes the whole page: `VERIFIED AGAINST CODE`, `PARTIALLY IMPLEMENTED`, or `DESIGN INTENT`. Section labels: `ESTABLISHED INTENT`, `DIRECTION`, `OPEN`, `RETIRED / DO NOT USE`.
7. **Code notes are dated.** A "verified against code" section names the commit it was checked at.
8. **Wiki vs. code conflicts.** If the wiki is only stale on a detail of current behavior, update it from the code. If the difference could be a design change, ask the owner.
9. **Thin tasks.** A task states what to build, links to the one wiki page that holds the design, and lists acceptance criteria. Design text belongs in the wiki, not in the task.
10. **Intent that affects gameplay or UI.** Record it in the wiki as `ESTABLISHED INTENT` before work starts, with a list of its undecided implementation details. Then compare it with the code and open one thin task per gap.
11. **Moving content.** Move content into the wiki before removing or merging any page. Delete duplicates instead of leaving pointer stubs, update every inbound link in the same commit, and add a row to the Migration log. Add no new information unless the owner states it; mark the rest `OPEN`. Do not edit files outside `docs/wiki/`.
12. **Checks.** Verify links and anchors case-sensitively against `git ls-files`, on Linux or CI (macOS ignores case).
