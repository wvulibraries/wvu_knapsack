# TASK: Commit all pending AI remediation changes
**Status**: BACKLOG
**Priority**: HIGH
**Type**: data
**Created**: 2026-04-06
**Last Updated**: 2026-04-06

---

## Agent Assignment

**Assigned To**: GPT-4.1 0x
**Why This Agent**: Git operations only — explicit file list and commit messages provided
**Supervision Level**: 🔴 Watched carefully

---

## Context

Multiple files were modified during the AI alt-text remediation feature development session. None have been committed yet. This task commits all working changes with appropriate messages. Run all git commands on the **host machine**, not inside containers.

---

## Files to Commit

Run this first to see current git status:
```bash
cd /Users/tam0013/Documents/git/wvu_knapsack
git status
git diff --stat
```

### Expected changed files (commit in this order):

**Commit 1 — Docker infrastructure fixes**
```bash
git add docker-compose.yml up.sc.local.sh
git commit -m "fix: docker-compose — add ingest mount to worker volumes, Solr healthcheck; up.sc.local — add yarn install wait loop"
```

**Commit 2 — AI remediation feature: core files**
```bash
git add app/models/concerns/ai_metadata_behavior.rb
git add app/models/file_set_decorator.rb
git add app/services/hyrax/listeners/ai_metadata_listener.rb
git add config/initializers/ai_metadata_listener.rb
git commit -m "feat: AI alt-text remediation — Valkyrie-compatible listener on file.characterized event"
```

**Commit 3 — Jobs updated for Valkyrie**
```bash
git add app/jobs/ai_description_job.rb
git add app/jobs/remediate_alt_text_job.rb
git add app/jobs/remediate_pdf_job.rb
git add app/jobs/ocr_pdf_job.rb
git commit -m "fix: AI remediation jobs — replace ActiveFedora FileSet.find_by with Valkyrie query_service pattern"
```

**Commit 4 — VisionService Valkyrie support**
```bash
git add app/services/vision_service.rb
git commit -m "feat: VisionService — add Valkyrie path for Hyrax::FileSet, improve prompt"
```

**Commit 5 — m3 schema (temporary testing addition)**
```bash
git add config/metadata_profiles/m3_profile.yaml
git commit -m "WIP: m3_profile — add alt_text for testing; to be replaced by native attribute in follow-up task"
```

**Commit 6 — Agent docs**
```bash
git add docs/
git commit -m "docs: add agent routing, task template, and backlog task files"
```

---

## Implementation Steps

### Step 1 — Verify no unexpected changes
```bash
git diff --name-only
```
Look for any files NOT in the list above. If there are unexpected changes, **stop and report** — do not commit unknown changes.

### Step 2 — Confirm hyrax-webapp is clean
```bash
git diff --name-only hyrax-webapp/
```
This should return nothing. If hyrax-webapp has changes, **stop and escalate** — do not commit changes to that submodule.

### Step 3 — Run commits in order above

### Step 4 — Verify
```bash
git log --oneline -10
git status
```
`git status` should show `nothing to commit, working tree clean`.

---

## Acceptance Criteria
- [ ] All 6 commits created with appropriate messages
- [ ] `git status` shows clean working tree
- [ ] `hyrax-webapp/` has zero commits (submodule not touched)
- [ ] No `git add .` used — only specific files added per commit

---

## Stop Conditions — escalate to user immediately if:
- Any unexpected files appear in `git status`
- `hyrax-webapp/` shows any modifications
- Git reports conflicts or detached HEAD state

---

## Dependencies
**Blocked by**: none
**Blocks**: nothing
**Related tasks**: all other backlog tasks

---

## Completion Report
*To be filled in by implementing agent*
