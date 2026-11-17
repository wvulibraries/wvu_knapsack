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

---

## Documentation

Full documentation lives in [docs/wiki/](docs/wiki/):

- **[Hyku Build Guide](docs/wiki/operations/hyku_build_guide.md)** — Setup, local testing (Stack Car + smoke test), and VM deployment
- **[Storage Architecture](docs/wiki/infrastructure/storage_architecture.md)** — Where data lives, backup/restore procedures, volume mount architecture

---

## Quick start

### Local development (Stack Car)

```bash
git clone --recurse-submodules https://github.com/wvulibraries/wvu_knapsack.git
cd wvu_knapsack
sc proxy up
sh up.sc.local.sh
# visit https://admin-wvu-knapsack.localhost.direct/
```

### VM production deployment

```bash
git clone --recurse-submodules https://github.com/wvulibraries/wvu_knapsack.git
cd wvu_knapsack
cp .env.production.example .env.production   # fill in real secrets
sh up.sh
sh scripts/setup.sh
```

See the [Hyku Build Guide](docs/wiki/operations/hyku_build_guide.md) for complete instructions.

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
└── docs/wiki/              # Full documentation (see above)
```

Any file with `_decorator.rb` in `app/` or `lib/` is loaded automatically alongside regular classes.

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

## Contributing

Open a pull request against `main`. For changes that are bugs or general improvements not specific to WVU, consider contributing them upstream to [samvera/hyku](https://github.com/samvera/hyku) or [samvera-labs/hyku_knapsack](https://github.com/samvera-labs/hyku_knapsack) instead.

## License

[Apache 2.0](https://opensource.org/license/apache-2-0/)