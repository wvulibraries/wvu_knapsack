# wvu_knapsack — Agent README
**Last Updated**: 2026-04-06
**Purpose**: Read this first. It tells you what this project is, where everything lives, and which document governs your role.

---

## What Is wvu_knapsack

**wvu_knapsack** is a Hyku-based digital repository *knapsack* (overlay) for West Virginia University Libraries. It runs on top of `hyrax-webapp` (maintained by Notch8). The knapsack adds WVU-specific models, indexers, jobs, services, views, and configuration without modifying the upstream submodule.

Current active initiative: **AI Accessibility Remediation** — automatically generating alt text for uploaded images and OCR text for PDFs using a locally-hosted Ollama (moondream) vision model.

---

## Your Role

The human will tell you your role in the session handoff. Find your document below and read it before doing anything else.

| Role | You Are | Read This |
|---|---|---|
| **Implementation Agent** | Fixing code, running containers, committing fixes | [`IMPLEMENTATION_AGENT_README.md`](IMPLEMENTATION_AGENT_README.md) |
| **Planning Agent** | Reviewing backlog, creating task files, routing work, producing handoffs | [`PLANNING_AGENT_README.md`](PLANNING_AGENT_README.md) |
| **Handoff Agent (scripted task)** | Working through a pre-scripted backlog task | [`tasks/handoff.md`](tasks/handoff.md) |

If your role is not specified in the handoff, ask before proceeding.

---

## 🚨 Mandatory Pre-Work Before Any Change

1. Read **this file** — understand what you are and aren't allowed to touch
2. Read your assigned role document above
3. Read `rules/ENVIRONMENT_BOUNDARIES.md` — command safety rules
4. Check the active task file in `tasks/active/` or the task given to you
5. **Do not modify `hyrax-webapp/` for any reason** — this is Notch8's submodule

---

## Critical Architecture Facts

These facts affect every task in this project. Misunderstanding any of these will waste your time.

| Fact | Detail |
|---|---|
| `HYRAX_FLEXIBLE=true` | Valkyrie mode — NOT ActiveFedora. No AR callbacks on Hyrax::FileSet. |
| FileSet class | `Hyrax::FileSet` (Valkyrie::Resource), not `FileSet` (ActiveFedora) |
| Multi-tenant | `AccountElevator.switch!('tenant_name')` required before any console data access |
| hyrax-webapp/ | Do NOT edit — it is a submodule maintained by Notch8 |
| Background jobs | GoodJob, not Sidekiq — queue with `perform_later`, check GoodJob dashboard |
| Ollama | Runs as a Docker service on internal port 11434 — not exposed to host |
| Persistence backend | Fedora (not Postgres) — `orm_resources` is empty; `find_all_of_model` iterates Solr then loads from Fedora |
| Solr model name | FileSets are indexed as `has_model_ssim:FileSet` (not `Hyrax::FileSet`) |

---

## Critical Rules — Every Agent

Violations have caused broken stacks and lost work in the past.

**1. All Rails/Ruby commands run inside Docker — no exceptions**
```bash
# Correct
docker compose exec web bundle exec rails console

# Git is the ONLY exception — runs on host directly
git add [files]
git commit -m "..."
```

**2. Never use `docker-compose exec` — always `docker compose exec`**
Use the V2 compose syntax. `docker-compose` (V1) is deprecated and behaves differently.

**3. Never edit `hyrax-webapp/`**
If a fix requires changing something in `hyrax-webapp/`, use a decorator in `app/models/`, `app/controllers/`, or `app/views/` in the knapsack root instead.

**4. Never add AR callbacks to Valkyrie resources**
`Hyrax::FileSet` inherits `Valkyrie::Resource` — it has no `after_save`, `after_create`, etc.
Use Hyrax event listeners via `Hyrax.publisher.subscribe` instead.

**5. Always use the Valkyrie query pattern**
```ruby
# Correct
fs = Hyrax.query_service.find_by(id: Valkyrie::ID.new(id_string))
Hyrax.persister.save(resource: fs)
Hyrax.index_adapter.save(resource: fs)

# WRONG — ActiveFedora pattern, will raise NoMethodError
fs = FileSet.find(id)
fs.save
```

**6. GoodJob concurrency guard**
`AiDescriptionJob` has `total_limit: 3` with key `'ollama_remediation'`. If console backfill is needed, use `AiDescriptionJob.new.perform(id)` directly, not `perform_later`.

**7. Never stream full RSpec output to chat**
Always redirect to a log file:
```bash
docker compose exec web bundle exec rspec spec/path/to_spec.rb > log/rspec_$(date +%s).log 2>&1
```

**8. Task file completion — move, never recreate**
When a task is done, `mv` the file from `tasks/backlog/` to `tasks/completed/`. Never copy and recreate.

---

## Project Structure

```
wvu_knapsack/
├── app/
│   ├── models/concerns/
│   │   └── ai_metadata_behavior.rb        ← marker concern (empty — logic in listener)
│   ├── models/
│   │   └── file_set_decorator.rb          ← wires AiMetadataBehavior into Hyrax::FileSet
│   ├── jobs/
│   │   ├── ai_description_job.rb          ← generates alt text via VisionService
│   │   ├── remediate_alt_text_job.rb      ← generates alt text when description already present
│   │   ├── remediate_pdf_job.rb           ← routes PDF to OCR
│   │   └── ocr_pdf_job.rb                 ← OCR extraction for PDFs
│   └── services/
│       ├── vision_service.rb              ← calls Ollama moondream vision model
│       └── hyrax/listeners/
│           └── ai_metadata_listener.rb   ← subscribes to file.characterized event
├── config/
│   ├── initializers/
│   │   └── ai_metadata_listener.rb       ← registers listener with Hyrax.publisher
│   └── metadata_profiles/
│       └── m3_profile.yaml               ← alt_text added here (temporary; needs refactor)
├── hyrax-webapp/                          ← DO NOT EDIT — Notch8 submodule
├── docs/agent/
│   ├── README.md                          ← this file
│   ├── AGENT_ROUTING.md                  ← agent roster, cost guide, full routing logic
│   ├── TASK_TEMPLATE.md                  ← canonical template for new task files
│   ├── IMPLEMENTATION_AGENT_README.md    ← implementation agent operating rules
│   ├── rules/
│   │   └── ENVIRONMENT_BOUNDARIES.md    ← command safety rules (read this)
│   └── tasks/
│       ├── active/                        ← currently assigned tasks
│       ├── backlog/                       ← queued tasks
│       ├── critical/                      ← high priority, start here if present
│       ├── completed/                     ← finished tasks, reference only
│       └── handoff.md                     ← GPT-4.1 backlog execution instructions
```

---

## Current Project State

> **Always check [`tasks/backlog/`](tasks/backlog/) for the live backlog.**

- **Stack**: Ruby 3.2.x, Rails, Fedora, Solr, Docker (all Rails work runs in container)
- **Active feature**: AI alt-text remediation pipeline
- **Pipeline status**: ✅ Listener fires, ✅ Jobs execute, ✅ alt_text saves to Fedora, ❌ HTML view not yet wired
- **Nothing committed yet** — commit task is first in backlog

### Backlog Summary (as of 2026-04-06)

| Priority | Task | Agent |
|---|---|---|
| HIGH | Commit all pending AI changes | GPT-4.1 |
| HIGH | Refactor alt_text: m3 → native Valkyrie attribute | Claude Sonnet |
| HIGH | Wire alt_text to img alt attribute in views | GPT-4.1 (after refactor) |
| MEDIUM | Validate/fix moondream vision prompt quality | GPT-4.1 |
| MEDIUM | Fix cleanup-dev.sh Solr volume removal | GPT-4.1 |
| LOW | Clean ghost Solr records in dev | GPT-4.1 |

---

## Agent Routing Quick Reference

Full routing guide: [`AGENT_ROUTING.md`](AGENT_ROUTING.md)

| Need | Use |
|---|---|
| Architecture decision (Valkyrie, Hyrax internals) | Claude Sonnet (1x) |
| Task file creation, session planning | Claude/Gemini web (free) |
| Single-file targeted fix, git ops, file moves | GPT-4.1 (0x) |
| Complex multi-file fix | Claude Sonnet (1x) |
| Stuck after 2 GPT-4.1 attempts | Claude Sonnet (1x) escalation |
| Research / Hyrax API lookup | Perplexity web (free) |

---

## Session Handoff

At the end of every session the agent produces a handoff note covering:
- What was completed (with commit SHAs if applicable)
- What was left incomplete and why
- Known issues discovered during the session
- Next priority task recommendation

Handoff documents live in `tasks/session-handoffs/` (create directory if it doesn't exist).
Check the most recent one before starting work each session.

---

## Hyrax/Valkyrie Quick Reference

```ruby
# Load a FileSet by Solr ID
fs = Hyrax.query_service.find_by(id: Valkyrie::ID.new("abc123"))

# Save a modified FileSet to Fedora
Hyrax.persister.save(resource: fs)

# Reindex a FileSet in Solr
Hyrax.index_adapter.save(resource: fs)

# Find FileMetadata for a file_id (from file.characterized event)
fm = Hyrax.custom_queries.find_file_metadata_by(id: Valkyrie::ID.new(file_id_string))
fm.original_file?  # => true if this is the original upload (not thumbnail/extracted text)

# Switch tenant in console
AccountElevator.switch!('testing')

# Solr query for FileSets
conn = Hyrax::SolrService.instance.conn
resp = conn.get('select', params: { q: 'has_model_ssim:FileSet', rows: 200, fl: 'id,alt_text_tesim' })
```

---

## Container Command Reference

| Task | Command |
|---|---|
| Rails console | `docker compose exec web bundle exec rails console` |
| Tail web logs | `docker compose logs -f web` |
| Tail worker logs | `docker compose logs -f worker` |
| Restart web+worker | `docker compose restart web worker` |
| Run specific spec | `docker compose exec web bundle exec rspec spec/path/to_spec.rb` |
| Check GoodJob queue | Visit `http://localhost:3000/jobs` (or configured path) |
| Git (all ops) | Run on **host directly** — never inside container |
