# Agent Handoff — AI Remediation Backlog
**Created**: 2026-04-06
**Updated**: 2026-04-06 (Task 2 reassigned to Grok; upstream m3 discovery)
**Task 1**: GPT-4.1 (0x) — git commits only
**Task 2**: Grok Code Fast (0.25x) — m3 conflict fix, exact code provided
**Task 3+**: GPT-4.1 (0x) — after Task 2 completes
**Session context**: AI alt-text remediation pipeline is complete and validated but nothing has been committed. All work is in working state on the dev stack.

---

## Before You Start — Read These First

1. [docs/agent/README.md](../README.md) — project overview and critical rules
2. [docs/agent/IMPLEMENTATION_AGENT_README.md](../IMPLEMENTATION_AGENT_README.md) — your operating rules
3. [docs/agent/rules/ENVIRONMENT_BOUNDARIES.md](../rules/ENVIRONMENT_BOUNDARIES.md) — command safety

**Stack is assumed to be running.** Verify:
```bash
docker compose ps
```
All services (web, worker, solr, fcrepo, ollama) should show as healthy/running.

---

## Current State Summary

The AI accessibility remediation pipeline is fully implemented and working:

- ✅ `Hyrax::Listeners::AiMetadataListener` fires on `file.characterized` event
- ✅ `AiDescriptionJob` enqueues via GoodJob and succeeds
- ✅ `VisionService` calls Ollama moondream and returns alt text
- ✅ `alt_text` saves to Fedora/Postgres via `Hyrax.persister.save`
- ❌ `alt_text` not yet a native Valkyrie attribute (currently in m3 schema — temp)
- ❌ HTML `<img alt="">` not yet reading `file_set.alt_text.first`
- ❌ Nothing committed yet

**Nothing in `git diff` should touch `hyrax-webapp/` — verify before any commit.**

---

## Backlog Task Order

| # | Priority | Task File | Agent | Notes |
|---|---|---|---|---|
| 1 | HIGH | `2026-04-06-HIGH-DATA-COMMIT-AI-REMEDIATION-CHANGES.md` | GPT-4.1 | Git only |
| 2 | HIGH | `2026-04-06-HIGH-REFACTOR-ALT-TEXT-M3-TO-NATIVE-ATTRIBUTE.md` | **Grok Code Fast** | Exact code provided below |
| 3 | HIGH | `2026-04-06-HIGH-FEATURE-ALT-TEXT-VIEW-WIRING.md` | GPT-4.1 | After task 2 only |
| 4 | MEDIUM | `2026-04-06-MEDIUM-BUG-FIX-VISION-PROMPT-QUALITY.md` | GPT-4.1 | |
| 5 | MEDIUM | `2026-04-06-MEDIUM-BUG-FIX-CLEANUP-SCRIPT-SOLR-VOLUME.md` | GPT-4.1 | |
| 6 | LOW | `2026-04-06-LOW-DATA-CLEANUP-GHOST-SOLR-RECORDS.md` | GPT-4.1 | |

Each agent stops after their task and reports before the next agent starts.

---

## Task 1: Commit All Pending Changes

**Full task file**: `docs/agent/tasks/backlog/2026-04-06-HIGH-DATA-COMMIT-AI-REMEDIATION-CHANGES.md`

### Pre-commit checks — run these first
```bash
cd /Users/tam0013/Documents/git/wvu_knapsack

# Verify nothing in hyrax-webapp/ is changed
git diff --name-only hyrax-webapp/
# MUST BE EMPTY — if anything shows, stop and report

# Review all changed files
git status
git diff --stat
```

### If git status looks clean, commit in this order:

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
git commit -m "fix: AI remediation jobs — replace ActiveFedora FileSet with Valkyrie query_service pattern"
```

**Commit 4 — VisionService Valkyrie support + prompt fix**
```bash
git add app/services/vision_service.rb
git commit -m "feat: VisionService — add Valkyrie path for Hyrax::FileSet, simplify prompt to avoid model echo artifact"
```

**Commit 5 — m3 schema (temporary testing addition)**
```bash
git add config/metadata_profiles/m3_profile.yaml
git commit -m "WIP: m3_profile — add alt_text for testing; to be replaced by native Valkyrie attribute in follow-up task"
```

**Commit 6 — Agent docs**
```bash
git add docs/
git commit -m "docs: add agent routing, task template, README, implementation guide, and AI remediation backlog task files"
```

### After committing
```bash
git log --oneline -8   # verify commit history looks correct
```

Report back with the output of `git log --oneline -8`.

### Task completion
```bash
mv docs/agent/tasks/backlog/2026-04-06-HIGH-DATA-COMMIT-AI-REMEDIATION-CHANGES.md \
   docs/agent/tasks/completed/2026-04-06-HIGH-DATA-COMMIT-AI-REMEDIATION-CHANGES.md
```

---

## Task 2: Remove conflicting alt_text from knapsack m3 profile (Grok Code Fast)

**Full task file**: `docs/agent/tasks/backlog/2026-04-06-HIGH-REFACTOR-ALT-TEXT-M3-TO-NATIVE-ATTRIBUTE.md`

### Context — read this first

**Discovery**: `hyrax-webapp/config/metadata_profiles/m3_profile.yaml` (line 353) already defines `alt_text` for `Hyrax::FileSet` with `alt_text_sim` and `alt_text_tesim` indexing. The block we added to the knapsack's own `config/metadata_profiles/m3_profile.yaml` (lines 1703–1735) is a duplicate with a conflicting `property_uri`. Remove the knapsack override and verify the upstream definition is sufficient.

**Do not edit `hyrax-webapp/`.**

### Step 1 — Remove the alt_text block from the knapsack m3 profile

File: `config/metadata_profiles/m3_profile.yaml`

Delete lines 1703–1735 — the entire `alt_text:` block shown below. The line just above it ends with `- example-split-from-pdf-id`. Remove from `  alt_text:` to the end of the `sample_values` entry (the last line of the file or the last entry before EOF):

```yaml
  alt_text:
    available_on:
      class:
      - Hyrax::FileSet
    cardinality:
      minimum: 0
      maximum: 1
    data_type: array
    controlled_values:
      format: http://www.w3.org/2001/XMLSchema#string
      sources:
      - 'null'
    definition:
      default: 'ADA-compliant alternative text for the file, generated by AI or provided manually.'
    display_label:
      default: Alt Text
    index_documentation: displayable, searchable
    indexing:
    - alt_text_tesim
    form:
      display: false
      primary: false
    property_uri: http://www.w3.org/1999/02/22-rdf-syntax-ns#altText
    range: http://www.w3.org/2001/XMLSchema#string
    sample_values:
    - A political cartoon depicting soldiers crossing a river.
```

### Step 2 — Verify the upstream definition still covers alt_text

The upstream profile at `hyrax-webapp/config/metadata_profiles/m3_profile.yaml` lines 353–370 has:
- `available_on: Hyrax::FileSet` ✅
- `indexing: alt_text_sim, alt_text_tesim` ✅
- `property_uri: https://schema.org/description`

No changes needed to `hyrax-webapp/`. Read it to confirm, do not edit it.

### Step 3 — Restart and verify boot

```bash
docker compose restart web worker
docker compose logs web --since=2m | grep -iE "error|Error" | grep -v "deprecat"
```

No boot errors expected. If you see errors related to `alt_text` or `m3_profile`, report them before continuing.

### Step 4 — Verify alt_text still accessible in console

```bash
docker compose exec web bundle exec rails runner \
  "AccountElevator.switch!('testing'); \
   fs = Hyrax.query_service.find_all_of_model(model: Hyrax::FileSet).first; \
   puts fs.respond_to?(:alt_text) ? 'OK: alt_text accessible' : 'FAIL: missing alt_text'"
```

Expected: `OK: alt_text accessible`

### Step 5 — Commit

```bash
git add config/metadata_profiles/m3_profile.yaml
git commit -m "fix: m3_profile — remove duplicate alt_text; upstream hyrax-webapp m3 profile already defines it for Hyrax::FileSet"
```

### Step 6 — Move task file and report

```bash
mv docs/agent/tasks/backlog/2026-04-06-HIGH-REFACTOR-ALT-TEXT-M3-TO-NATIVE-ATTRIBUTE.md \
   docs/agent/tasks/completed/2026-04-06-HIGH-REFACTOR-ALT-TEXT-M3-TO-NATIVE-ATTRIBUTE.md
git add docs/agent/tasks/
git commit -m "docs: mark alt_text m3 refactor task as completed"
```

Report the console output from Step 4 and the commit SHA. **Stop — do not continue to Task 3.**

---

## Task 3: Wire alt_text to img alt attribute (wait for Task 2 first)

**Full task file**: `docs/agent/tasks/backlog/2026-04-06-HIGH-FEATURE-ALT-TEXT-VIEW-WIRING.md`

**Do not start this until Task 2 is confirmed complete.** This task depends on `alt_text` being verified accessible on FileSet.

When handed this task, the work is:
1. Find the view partial(s) that render FileSet `<img>` tags
2. Add `alt: file_set.alt_text.first.presence || file_set.title.first` to the img tag
3. Restart web: `docker compose restart web`
4. Visually verify in browser that alt text appears on a FileSet image
5. Commit and move task file

### How to find the img tag:
```bash
# Search knapsack views first
grep -r "image_tag\|<img" app/views/ --include="*.erb" -l

# If not overridden in knapsack, check hyrax-webapp views (read-only reference)
grep -r "image_tag\|<img" hyrax-webapp/app/views/ --include="*.erb" -l
```

If the image tag lives only in `hyrax-webapp/`, you must override the partial in the knapsack (copy to `app/views/` with same relative path), then edit the copy. **Do not edit hyrax-webapp/ directly.**

---

## Task 4: Validate Vision Prompt Quality

**Full task file**: `docs/agent/tasks/backlog/2026-04-06-MEDIUM-BUG-FIX-VISION-PROMPT-QUALITY.md`

The current prompt in `app/services/vision_service.rb` was changed from a complex negative instruction (which caused the model to echo `"!!!IMAGE OF!!!"`) to a simple positive prompt:
```
"Briefly describe what is shown in this image in one concise sentence under 125 characters."
```

The task is to validate the prompt quality by running it against a real FileSet image and reviewing the output.

```ruby
# In console
AccountElevator.switch!('testing')

# Find a FileSet with a known image
conn = Hyrax::SolrService.instance.conn
resp = conn.get('select', params: { q: 'has_model_ssim:FileSet', rows: 5, fl: 'id,title_tesim' })
sample_id = resp['response']['docs'].first['id']

# Run the job directly
AiDescriptionJob.new.perform(sample_id)

# Check the result
fs = Hyrax.query_service.find_by(id: Valkyrie::ID.new(sample_id))
puts fs.alt_text
```

If the output is coherent and under 125 characters, task is done. If not, adjust the prompt constant in `vision_service.rb`.

---

## Task 5: Fix cleanup-dev.sh Solr Volume Removal

**Full task file**: `docs/agent/tasks/backlog/2026-04-06-MEDIUM-BUG-FIX-CLEANUP-SCRIPT-SOLR-VOLUME.md`

The `scripts/cleanup-dev.sh` script fails to remove the Solr volume. Read the script, identify why the volume removal fails, and fix it.

```bash
# Read the script
cat scripts/cleanup-dev.sh

# Check what volumes exist for reference
docker volume ls | grep knapsack
```

Typically the issue is: the volume name in the script doesn't match the actual Docker volume name (which includes the compose project prefix). Fix the script to use the correct volume name or use a pattern match.

---

## Task 6: Clean Ghost Solr Records (LOW priority — optional)

**Full task file**: `docs/agent/tasks/backlog/2026-04-06-LOW-DATA-CLEANUP-GHOST-SOLR-RECORDS.md`

~130 Solr records from an earlier failed import exist in the dev Solr index. These have valid Solr entries but no corresponding Fedora objects. They cause confusing results in the admin UI but don't break anything.

Only do this task if all higher priority tasks are complete and the user specifically asks for it.

---

## Rules for This Session

1. **Git runs on host only** — all other commands use `docker compose exec web`
2. **Never touch `hyrax-webapp/`**
3. **For each task**: read the task file, propose what you'll do, wait for approval, then execute
4. **After each commit**: run `git log --oneline -3` and report the result
5. **When stuck**: report the exact error and current code, do not attempt a third approach — escalate to user
6. **Task 2 is not yours**: if the user hands you task 2, tell them it should go to Claude Sonnet

---

## Quick Diagnostic Commands

```bash
# Is the stack up?
docker compose ps

# Any boot errors after a change?
docker compose logs web --since=2m | grep -E "ERROR|error|Error"

# Is the listener registered?
docker compose exec web bundle exec rails runner \
  "puts Hyrax.publisher.subscribers.map(&:class)"

# Is GoodJob processing?
docker compose logs worker --since=5m | grep -E "GoodJob|perform|error" | tail -20

# Find a test FileSet ID from Solr
docker compose exec web bundle exec rails runner \
  "AccountElevator.switch!('testing'); \
   r = Hyrax::SolrService.instance.conn.get('select', params: {q: 'has_model_ssim:FileSet', rows: 1, fl: 'id'}); \
   puts r['response']['docs'].first['id']"
```
