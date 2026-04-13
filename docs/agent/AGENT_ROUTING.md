# Agent Routing Guide & Documentation Index
**Last Updated**: 2026-04-06

**Purpose**: Route work to the right agent. Check task backlog before starting any session.

---

## Project Context

**wvu_knapsack** is a Hyku-based digital repository knapsack (overlay) for West Virginia University Libraries. It runs on top of `hyrax-webapp` (maintained by Notch8 — do not modify). The knapsack adds WVU-specific models, indexers, jobs, services, and configuration.

**Critical architecture facts** (read before any task):
- `HYRAX_FLEXIBLE=true` — Valkyrie mode, NOT ActiveFedora
- FileSet class is `Hyrax::FileSet` (Valkyrie), not `FileSet` (ActiveFedora)
- Multi-tenant: `AccountElevator.switch!('tenant_name')` required in console before any data access
- Do NOT edit anything in `hyrax-webapp/` — it is Notch8's submodule
- GoodJob for background jobs (not Sidekiq)
- Ollama runs as a Docker service (internal port 11434, not exposed)

---

## Agent Roster & Routing

### Web Agents — Free, No Request Limits

| Agent | Primary Role | Use For |
|---|---|---|
| **Claude** (claude.ai) | Session Strategist, Planner | Session triage, architecture decisions, task file creation, handoff summaries |
| **Perplexity** (web) | Research | Issue diagnosis, Hyrax/Valkyrie API lookup, Ruby patterns |
| **Gemini** (web) | Documentation | Documentation synthesis, brainstorming |
| **ChatGPT** (web) | Planning support | High-level design, task decomposition |

> Web agents do not touch code or run commands. They create task files and hand off to Copilot agents.

---

### Copilot Agents — Premium, Watch Request Burn

| Agent | Cost | Capability | Best For | Supervision |
|---|---|---|---|---|
| **GPT-4.1** | 0x | Good, needs guidance | Targeted single-file fixes, commits, file ops, greps | 🔴 Watched carefully |
| **GPT-4o** | 0x | Untested | Try for medium complexity — evaluate before relying on | 🔴 Watched carefully |
| **Grok Code Fast** | 0.25x | Better than GPT-4.1 | Complex multi-file fixes after GPT-4.1 fails twice | 🟡 Standard |
| **Claude Haiku 4.5** | 0.33x | Fast, limited | Simple reasoning tasks only | 🟡 Standard |
| **Gemini Flash** | 0.33x | Good autonomy | Avoid — use Gemini web instead | 🟡 Standard |
| **Claude Sonnet 4.6** | 1x | Strong reasoning | Complex fixes, Valkyrie/Hyrax architecture, stuck agents | 🟢 Trusted |
| **Claude Opus 4.5/4.6** | 3x | Highest capability | Genuine deadlocks only — Sonnet couldn't resolve | 🟢 Trusted |

**Supervision Legend**:
- 🔴 Watched carefully = verify every output before accepting
- 🟡 Standard = review outputs, apply judgment
- 🟢 Autonomous OK = can work from lean task file

---

### Local Agents — Free

| Agent | Primary Role | Notes |
|---|---|---|
| **Ollama** (moondream) | Vision AI | Already deployed in Docker stack — generates alt text |
| **Ollama** (llama3.1:70B) | Autonomous grinder | Overnight batch runs if configured |

---

## Routing Decision Guide

```
What kind of work is this?

PLANNING / ARCHITECTURE / TASK CREATION?
  └─ Claude web (free) — stays here, produces task file

RESEARCH / HYRAX API LOOKUP / ISSUE DIAGNOSIS?
  └─ Perplexity web (free)

DOCUMENTATION?
  └─ Gemini web (free) — preferred

IMPLEMENTATION — how complex is the task?

  Fully specified, single file, clear fix?
    └─ GPT-4.1 (0x) — free, watch carefully
       Task file must be COMPLETE — explicit paths, methods, commands

  Same failure after 2 GPT-4.1 attempts?
    └─ Grok Code Fast (0.25x) — better capability, worth the cost

  Complex root cause, Valkyrie/Hyrax architecture judgment needed?
  Grok failed or unavailable?
    └─ Claude Sonnet (1x) — spend deliberately

  Hardest problems only, Sonnet couldn't resolve?
    └─ Claude Opus (3x) — last resort only
```

---

## Request Budget Rules

1. **Always start with the cheapest capable agent** — GPT-4.1 first, always
2. **Escalate when stuck** — same failure after 2 attempts = move up one tier
3. **Grok Code Fast is the first escalation** — not Gemini Flash, not Sonnet
4. **Claude Sonnet is the senior agent** — not the default, use for complexity
5. **Never use Opus until Sonnet is genuinely stuck** — 3x cost, last resort
6. **Web agents are free** — Claude, Perplexity, Gemini web have no limit
7. **Never escalate to premium for diagnosis** — Claude web diagnoses, GPT-4.1 executes
8. **Never touch hyrax-webapp/** — escalate to user if a task requires it

---

## Task File Depth by Agent

A 0x agent handed a lean task file will burn requests on clarification.
**When in doubt — over-specify. It never hurts.**

| Agent | File Paths | Method Names | Step-by-Step Commands | Architecture Context |
|---|---|---|---|---|
| **GPT-4.1 (0x)** | Exact | Exact + line numbers | Every command explicit | Full summary |
| **Grok (0.25x)** | Exact | Exact | Most commands explicit | Full summary |
| **Claude Sonnet (1x)** | Approximate | Can infer | Key commands | High level OK |
| **Claude Opus (3x)** | High level OK | Can infer | Key commands | High level OK |

---

## Knapsack-Specific Rules for All Agents

1. **Never edit `hyrax-webapp/`** — it is Notch8's maintained submodule
2. **Use `Hyrax::FileSet` not `FileSet`** — the bare `FileSet` class triggers Wings errors in flexible mode
3. **Always call `AccountElevator.switch!('tenant')` in console** before any data query
4. **Valkyrie persister pattern**:
   ```ruby
   resource = Hyrax.query_service.find_by(id: Valkyrie::ID.new(id_string))
   resource.some_attr = 'value'
   Hyrax.persister.save(resource: resource)
   Hyrax.index_adapter.save(resource: resource)
   ```
5. **Solr field names for FileSet use `_tesim` suffix** — e.g. `alt_text_tesim`
6. **GoodJob concurrency key** — all Ollama jobs share `'ollama_remediation'` key with `OLLAMA_NUM_PARALLEL` limit

---

## Documentation Index

### `/docs/agent` — Agent Operations
| Path | Purpose |
|---|---|
| `agent/AGENT_ROUTING.md` | This file — route work, check before every session |
| `agent/TASK_TEMPLATE.md` | Canonical task file template |
| `agent/tasks/backlog/` | Queued tasks — start here |
| `agent/tasks/active/` | Currently assigned tasks |
| `agent/tasks/critical/` | High priority tasks |
| `agent/tasks/completed/` | Finished tasks, reference only |

### Key Source Files
| Path | Purpose |
|---|---|
| `app/models/concerns/ai_metadata_behavior.rb` | AI alt-text concern (minimal — logic in listener) |
| `app/models/file_set_decorator.rb` | Wires AiMetadataBehavior into Hyrax::FileSet |
| `app/services/hyrax/listeners/ai_metadata_listener.rb` | Hyrax event listener for file.characterized |
| `app/services/vision_service.rb` | Ollama/Moondream vision AI integration |
| `app/services/alt_text_generator_service.rb` | Text-based alt text via Ollama |
| `app/jobs/ai_description_job.rb` | Vision alt text job (images, no description) |
| `app/jobs/remediate_alt_text_job.rb` | Text summarization job (has description) |
| `app/jobs/remediate_pdf_job.rb` | PDF alt text job |
| `app/jobs/ocr_pdf_job.rb` | OCR stage 1 for PDFs |
| `config/initializers/ai_metadata_listener.rb` | Registers AiMetadataListener |
| `config/metadata_profiles/m3_profile.yaml` | Flexible metadata schema (alt_text added here for testing) |
| `docker-compose.yml` | Main compose — extends hyrax-webapp/docker-compose.yml |
| `up.sc.local.sh` | Stack startup script |
