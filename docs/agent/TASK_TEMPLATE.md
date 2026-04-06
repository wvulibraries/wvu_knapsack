# Task File Template
# Copy this file, rename it to describe the task, fill in all sections.
# Delete these instruction comments before saving.
# Place in docs/agent/tasks/backlog/, critical/, or active/ as appropriate.
#
# FILENAME CONVENTION — mandatory for all task files:
#   YYYY-MM-DD-PRIORITY-TYPE-DESCRIPTIVE-NAME.md
#
#   YYYY-MM-DD  = date the task was created
#   PRIORITY    = CRITICAL | HIGH | MEDIUM | LOW
#   TYPE        = bug-fix | feature | refactor | architecture | data | documentation
#   NAME        = kebab-case, descriptive, no spaces
#
#   Examples:
#     2026-04-06-HIGH-FEATURE-ALT-TEXT-VIEW-WIRING.md
#     2026-04-06-MEDIUM-REFACTOR-ALT-TEXT-M3-TO-SCHEMA.md
#     2026-04-06-LOW-BUG-FIX-VISION-PROMPT-QUALITY.md
#
#   Why this matters:
#     - Date = recency signal. Stale tasks may predate architecture decisions.
#     - Priority = triage at a glance without opening the file.
#     - No date prefix = task must be reviewed before assignment, may be obsolete.
#
# ⚠️ Files without this convention will not be assigned until renamed and reviewed.
#
# DEPTH GUIDE — how much detail to include per agent tier:
#   0x  (GPT-4.1)       — fill every field, no ambiguity, explicit paths and commands
#   0.25x (Grok)        — fill every field, commands can be slightly abbreviated
#   0.33x (Gemini Flash)— most fields required, can handle some inference
#   1x  (Claude Sonnet) — core fields required, can reason about gaps
#   3x  (Claude Opus)   — reserve for hardest problems, lean task file is fine
#
# Rule: when in doubt, add more detail.
# An over-specified task wastes nothing. An under-specified task burns premium requests.

---

# TASK: [Short descriptive title]
**Status**: BACKLOG | ACTIVE | BLOCKED | COMPLETED
**Priority**: CRITICAL | HIGH | MEDIUM | LOW
**Type**: bug-fix | feature | refactor | architecture | data | documentation
**Created**: YYYY-MM-DD
**Last Updated**: YYYY-MM-DD

---

## Agent Assignment

**Assigned To**: [GPT-4.1 0x | Grok 0.25x | Claude Sonnet 1x | Claude Opus 3x]
**Why This Agent**: [one line — e.g. "single-file fix, fully specified" or "requires Valkyrie architecture reasoning"]
**Supervision Level**: [watched carefully | standard | autonomous OK]

**Supervision Legend**:
- 🔴 Watched carefully = 0x agents — verify every file change before accepting
- 🟡 Standard = 0.25x–0.33x agents — review outputs, apply judgment
- 🟢 Autonomous OK = 1x agents — can work from lean task file

> ⚠️ 0x agents: read every section carefully before starting.
> Do not infer file paths or method names — they are provided explicitly below.
> Do NOT edit anything in `hyrax-webapp/` — it is Notch8's submodule.

---

## Context

[2–4 sentences explaining what this part of the system does and why this task exists.
For 0x agents: be explicit. For 1x agents: high-level is fine.]

**Critical architecture facts for this task**:
- App runs `HYRAX_FLEXIBLE=true` — Valkyrie mode, not ActiveFedora
- FileSet class is `Hyrax::FileSet` (Valkyrie) — do NOT use bare `FileSet`
- Multi-tenant: `AccountElevator.switch!('testing')` required in console before any query
- Valkyrie lookup: `Hyrax.query_service.find_by(id: Valkyrie::ID.new(id_string))`
- Valkyrie save: `Hyrax.persister.save(resource: resource)`
- Valkyrie reindex: `Hyrax.index_adapter.save(resource: resource)`

**Relevant files** — read before starting:
- `docs/agent/AGENT_ROUTING.md` — routing rules and architecture facts

---

## Problem Statement

[Exact description of what is wrong or missing. For bug fixes: include the error message verbatim. For features: describe the missing behavior precisely.]

**Error output** (if applicable):
```
[paste exact error here]
```

**Current behavior**: [what happens now]
**Expected behavior**: [what should happen]

---

## Files Involved

### Primary Files — you will edit these
| File | Purpose | Key Method/Section |
|---|---|---|
| `app/[path]/[file].rb` | [what it does] | `#method_name` line ~N |

### Reference Files — read but do not edit
| File | Why You Need It |
|---|---|
| `hyrax-webapp/app/[path]/[file].rb` | [context only — do not edit] |

### ⚠️ Do Not Touch
- Anything under `hyrax-webapp/` — Notch8's submodule, changes will be overwritten

---

## Implementation Steps

> 0x agents: follow these steps exactly in order.
> 1x agents: use as a guide, apply judgment.

### Step 1 — [action]
[Exact description of what to do]

```ruby
# Before
old_code

# After
new_code
```

### Step 2 — [action]
[Exact description]

### Step 3 — Verify in Rails console
```bash
docker compose exec web bundle exec rails console
```
```ruby
AccountElevator.switch!('testing')
# [verification commands]
```

Expected result: [what you should see]

---

## Acceptance Criteria
- [ ] [specific measurable outcome]
- [ ] [specific measurable outcome]
- [ ] No errors on container restart (`docker compose restart web worker`)
- [ ] Verified in Rails console or browser

---

## Stop Conditions — escalate to user immediately if:
- Fix causes unexpected errors in other parts of the system
- Same failure persists after two attempts — report exact error, do not attempt a third fix
- Root cause is in `hyrax-webapp/` — do not modify, escalate
- Any architectural decision is required that isn't covered in this task file
- A database migration is needed that wasn't anticipated

---

## Docker Commands Reference

```bash
# Restart web and worker (picks up code changes — no rebuild needed, code is volume-mounted)
docker compose restart web worker

# Rails console
docker compose exec web bundle exec rails console

# Watch worker logs
docker compose logs -f worker | grep -E "AiDescription|RemediateAlt|VisionService|Error"

# Check GoodJob queue
# In rails console:
GoodJob::Job.where(queue_name: 'ai_remediation').order(created_at: :desc).limit(10).pluck(:job_class, :finished_at, :error)
```

---

## Commit Instructions
Run git commands on **host**, not inside container:
```bash
git add [specific files only — never git add .]
git commit -m "[type]: [file name] — [brief description of change]"
```

Example good commit: `fix: ai_description_job — use Valkyrie persister instead of AF save`
Example bad commit: `fix stuff`

---

## Dependencies
**Blocked by**: [task filename or "none"]
**Blocks**: [task filename or "none"]
**Related tasks**: [task filename or "none"]

---

## Completion Report
*Filled in by the implementing agent after completion*

**Completed by**: [agent name]
**Completion date**: YYYY-MM-DD

### What was changed
- `[file]` — [description of change]

### Issues discovered
[Any problems found during implementation not covered in the original task]

### Follow-up tasks needed
[New backlog items identified — do not create the files, just list them here]

### Lessons learned
[What worked, what didn't, what future tasks in this area should know]
