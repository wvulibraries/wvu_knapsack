# Environment Boundaries — Command Safety Rules
**Last Updated**: 2026-04-06
**Version**: 1.0
**Applies to**: All agents working on wvu_knapsack

---

## The Fundamental Rule

**All Rails, Ruby, rake, and bundle commands run inside Docker containers.**
**Git is the only exception — it runs on the host.**

This is not optional. Running Ruby commands on the host will fail silently or corrupt your local Ruby environment.

---

## Container Command Form

Always use Docker Compose V2 (space syntax):

```bash
# Correct — V2 syntax
docker compose exec web bundle exec rails console
docker compose exec web bundle exec rspec spec/path/to_spec.rb
docker compose exec worker bundle exec rails runner "..."

# WRONG — V1 syntax (deprecated)
docker-compose exec web bundle exec rspec
```

**Never use `docker-compose` (hyphen form).** The V1 syntax is deprecated and has caused dev database corruption in similar projects.

---

## Service Names

| Service | Purpose | Exec Into |
|---|---|---|
| `web` | Rails application server | `docker compose exec web bash` |
| `worker` | GoodJob background worker | `docker compose exec worker bash` |
| `solr` | Solr search (SolrCloud) | `docker compose exec solr bash` |
| `fcrepo` | Fedora Commons repository | `docker compose exec fcrepo bash` |
| `ollama` | Ollama LLM/vision service | `docker compose exec ollama bash` |
| `db` | PostgreSQL | `docker compose exec db psql -U postgres` |
| `redis` | Redis cache/queue | `docker compose exec redis redis-cli` |
| `zk` | ZooKeeper (Solr cluster) | — |

---

## What Runs Where

| Command Type | Runs On | Example |
|---|---|---|
| Rails console | Container (web) | `docker compose exec web bundle exec rails console` |
| RSpec | Container (web) | `docker compose exec web bundle exec rspec spec/` |
| rake tasks | Container (web) | `docker compose exec web bundle exec rake db:migrate` |
| bundle install | Container (web) | `docker compose exec web bundle install` |
| rails runner | Container (web or worker) | `docker compose exec web bundle exec rails runner "puts 'hello'"` |
| git add/commit/push | **Host** | `git add app/services/` |
| git log/status/diff | **Host** | `git status` |
| cat/grep/ls (inspection) | Either | Prefer host for knapsack files; use container for runtime paths |

---

## Forbidden Commands

```bash
# NEVER — runs Ruby on the host
bundle exec rspec
bundle exec rails console
rails c

# NEVER — V1 compose syntax
docker-compose exec web bundle exec rspec

# NEVER — start/stop full stack (use targeted restarts only)
docker compose down
docker compose up
./down.sh   # unless explicitly asked by user

# NEVER — inside the container
docker compose exec web bash -c 'git commit ...'
docker compose exec web bash -c 'git push'
```

---

## Safe Container Management

**You may restart specific services after a code change:**
```bash
docker compose restart web worker
```

**You may check service status:**
```bash
docker compose ps
docker compose logs web --since=5m
docker compose logs worker --since=5m
```

**Do NOT start, stop, or recreate the full stack** without explicit user instruction. The stack may be serving a live import or running GoodJob tasks.

---

## Volume and Data Safety

**Never run `docker volume rm` without explicit user instruction.**
The `data/` directory on the host contains Fedora objects, Solr indexes, Redis data, and uploaded files. Removing a volume destroys all of this.

Reference only — for cleanup scripts:
```bash
# Check volume names before any rm
docker volume ls | grep knapsack
# Never run docker volume rm without verifying the exact volume name first
```

---

## `hyrax-webapp/` Is Read-Only

The `hyrax-webapp/` directory is a Git submodule maintained by Notch8. It is mounted directly into the container.

- **Never edit files inside `hyrax-webapp/`** — changes will be lost on next submodule update
- **To override any hyrax-webapp behavior**: create a file at the same relative path in the knapsack root's `app/` directory
  - Example: to override `hyrax-webapp/app/views/hyrax/file_sets/_media.html.erb`, create `app/views/hyrax/file_sets/_media.html.erb` in the knapsack root
- **To check what a view currently does**: read `hyrax-webapp/app/views/...` (read-only reference)

---

## Multi-Tenant Console Access

This application is multi-tenant. Querying data without switching tenant context returns empty results with no error — a silent failure that wastes debugging time.

**Always switch tenant first:**
```ruby
AccountElevator.switch!('testing')  # replace 'testing' with actual tenant slug

# Then query
fs = Hyrax.query_service.find_by(id: Valkyrie::ID.new("abc123"))
```

**Tenant slugs** in the dev environment: check `accounts` table or ask user.

---

## GoodJob Queue Safety

`AiDescriptionJob` has a `total_limit: 3` concurrency guard with key `'ollama_remediation'`. This means:

- Only 3 AI jobs can be queued or running at the same time
- `perform_later` will silently drop jobs when the limit is hit
- For **console backfill**, use `perform_now` instead:

```ruby
# Console backfill — use this pattern
AiDescriptionJob.new.perform("file-set-id-string")

# Do NOT use this for backfill (silently dropped when queue full)
AiDescriptionJob.perform_later("file-set-id-string")
```

---

## Solr Query Safety

Solr in this stack runs in SolrCloud mode with ZooKeeper. The standard query client:

```ruby
conn = Hyrax::SolrService.instance.conn
resp = conn.get('select', params: { q: 'has_model_ssim:FileSet', rows: 200, fl: 'id,title_tesim' })
docs = resp['response']['docs']
```

**Solr model name note**: FileSets are indexed as `has_model_ssim:FileSet` (not `Hyrax::FileSet`).

**Never run Solr delete queries** on the dev index without explicit user instruction — deleted records cannot be recovered without a full Fedora re-index.

---

## Log File Policy

For large RSpec runs, always redirect output to a file:

```bash
docker compose exec web bundle exec rspec spec/jobs/ \
  > log/rspec_jobs_$(date +%s).log 2>&1

# Then inspect
tail -50 log/rspec_jobs_[timestamp].log
grep -E "failure|error|FAILED" log/rspec_jobs_[timestamp].log
```

**Never stream full RSpec output to the VS Code chat buffer.** It has caused buffer crashes. Single spec files are OK to stream; anything larger should be redirected.
