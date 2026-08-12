# WVU Libraries Hyku Knapsack

This is the [WVU Libraries](https://libraries.wvu.edu) instance of [Hyku](https://github.com/samvera/hyku), managed as a [Hyku Knapsack](https://github.com/samvera-labs/hyku_knapsack).

| | |
|---|---|
| **Repository** | https://github.com/wvulibraries/wvu_knapsack |
| **Hyku submodule** | `./hyrax-webapp` → https://github.com/samvera/hyku |
| **Upstream knapsack template** | `prime` remote → https://github.com/samvera-labs/hyku_knapsack |
| **Production admin URL** | https://admin-hyku.lib.wvu.edu |
| **Production host** | `*.lib.wvu.edu` |
| **APP_NAME** | `wvu-knapsack` |

> **Full documentation:**
> - [HYKU_BUILD_GUIDE.md](HYKU_BUILD_GUIDE.md) — Setup, local testing, and VM deployment
> - [STORAGE_ARCHITECTURE.md](STORAGE_ARCHITECTURE.md) — Where data lives, backup/restore procedures

---

## How this repo is structured

The knapsack pattern keeps WVU-specific code isolated from Hyku core (the `./hyrax-webapp` submodule). Files in the knapsack are loaded at higher precedence than the underlying Hyku application, so they transparently override views, controllers, models, and configuration without modifying Hyku itself.

```
wvu_knapsack/
├── app/                    # WVU overrides/decorators (views, models, controllers, etc.)
├── config/                 # WVU-specific Rails initializers and routes
├── bundler.d/              # Additional gems (add here, never in Gemfile/gemspec)
├── hyrax-webapp/           # Hyku core — Git submodule, do not edit
├── docker-compose.production.yml
├── .env.production.example # Environment template — copy to .env.production
├── scripts/setup.sh        # One-time DB/Solr/tenant setup
├── up.sh / down.sh         # VM production start/stop
├── up.sc.local.sh / down.sc.local.sh   # Stack Car dev rebuild/start/stop
├── up.prod.local.sh / down.prod.local.sh # Local production smoke test
└── HYKU_BUILD_GUIDE.md     # Complete developer and DevOps guide
```

Any file with `_decorator.rb` in `app/` or `lib/` is loaded automatically alongside regular classes.

---

## Prerequisites

- Docker Desktop
- [Stack Car](https://github.com/samvera-labs/stack_car): `gem install stack_car`
- Ruby (for running `sc` commands locally)

---

## Quick start — local development (Stack Car)

All commands run from the **knapsack root**, never from inside `hyrax-webapp`.

### 1. Clone with submodule

```bash
git clone --recurse-submodules https://github.com/wvulibraries/wvu_knapsack.git
cd wvu_knapsack
```

If you already cloned without `--recurse-submodules`:

```bash
git submodule update --init --recursive
```

### 2. Create the required knapsack branch

This branch must exist locally for the bundler shim to work:

```bash
git fetch prime
git checkout prime/required_for_knapsack_instances
git switch -c required_for_knapsack_instances
git checkout main   # return to main
```

### 3. Set up the Stack Car dev proxy (once per machine)

```bash
sc proxy cert
sc proxy up
```

### 4. Build and start

```bash
sh up.sc.local.sh   # builds web + worker images (--no-cache), then sc up -d
```

Or step by step:

```bash
sc pull    # pull latest base images
sc build   # build local image
sc up      # start the stack
```

### 5. Open the app

```
https://admin-wvu-knapsack.localhost.direct/
```

Default admin credentials (development): see `hyrax-webapp/.env` or the build guide.

### 6. Useful Stack Car commands

```bash
sc sh              # shell into the web container
sc exec web rails console
sc logs -f web
sh down.sc.local.sh  # tear everything down
```

---

## Quick start — local production smoke test

See [HYKU_BUILD_GUIDE.md § Local Production Smoke Testing](HYKU_BUILD_GUIDE.md) for the full walkthrough. In brief:

```bash
cp .env.production.example .env.production   # edit with local values
cp .env.db.example .env.db && cp .env.redis.example .env.redis
cp .env.solr.example .env.solr && cp .env.fedora.example .env.fedora
docker compose -f docker-compose.local.yml up -d
docker compose -f docker-compose.local.yml exec web sh /app/samvera/scripts/setup.sh
# visit http://admin-wvu-knapsack.lvh.me:3000
```

---

## Quick start — VM production deployment

See [HYKU_BUILD_GUIDE.md § VM Production Deployment](HYKU_BUILD_GUIDE.md) for the complete DevOps checklist. In brief:

```bash
git clone --recurse-submodules https://github.com/wvulibraries/wvu_knapsack.git
cd wvu_knapsack
cp .env.production.example .env.production   # fill in real secrets + lib.wvu.edu hosts
sh up.sh            # pulls, updates submodule, starts docker-compose.production.yml
sh scripts/setup.sh
```

---

## Making WVU-specific changes

### Overriding views, controllers, models

Copy the file from `hyrax-webapp/` into the same relative path inside the knapsack and modify it. Add an override comment at the top so it's clear why the file exists:

```ruby
# OVERRIDE Hyku v<version> — reason for override
```

Best practices: [Decorators and Overrides wiki](https://github.com/samvera-labs/hyku_knapsack/wiki/Decorators-and-Overrides)

### Adding gems

Add gems to [bundler.d/](bundler.d/) — do **not** edit `Gemfile` or the gemspec. Adding to those files modifies Hyku's bundle and causes drift.

```ruby
# bundler.d/wvu.rb
gem 'some-gem'
```

See [bundler-inject docs](https://github.com/kbrock/bundler-inject/) for details.

### Adding custom work types

```bash
bundle exec rails generate hyku_knapsack:work_resource WorkType
```

Files are created in the knapsack directory, not in `hyrax-webapp`.

### Updating the Hyku submodule to a new version

```bash
cd hyrax-webapp
git fetch origin
git checkout <new-sha-or-branch>
cd ..
git add hyrax-webapp
git commit -m "Bump Hyku submodule to <version>"
```

### Pulling updates from knapsack prime

```bash
git fetch prime
git merge prime/main   # or: git rebase prime/main
git push origin main
```

---

## Key configuration files

| File | Purpose | Committed? |
|---|---|---|
| `.env.production.example` | Template for all env vars | Yes |
| `.env.production` | Live env (local or VM) | No (gitignored) |
| `config/initializers/host_authorization.rb` | Allow `*.lib.wvu.edu` + `HYKU_EXTRA_HOSTS` | Yes |
| `config/initializers/session_store_override.rb` | Disable Secure cookie over HTTP when `DISABLE_FORCE_SSL=true` | Yes |
| `docker-compose.production.yml` | Production stack (Solr, Fedora, DB, Redis, web, worker) | Yes |
| `scripts/setup.sh` | One-time DB/Solr/tenant initialization | Yes |

---

## Contributing

Open a pull request against `main`. For changes that are bugs or general improvements not specific to WVU, consider contributing them upstream to [samvera/hyku](https://github.com/samvera/hyku) or [samvera-labs/hyku_knapsack](https://github.com/samvera-labs/hyku_knapsack) instead.

## License

[Apache 2.0](https://opensource.org/license/apache-2-0/)