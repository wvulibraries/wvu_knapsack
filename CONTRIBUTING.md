# Contributing to WVU Knapsack

## Local Development Setup

### Stack Car Development (Recommended)

This repository is optimized for local development using **Stack Car** with **Traefik** for local HTTPS.

**Prerequisites:**
- Docker & Docker Compose
- Ruby 3.3.0 (see Ruby version management below)
- Stack Car gem: `gem install stack_car`

**Starting the Stack:**
```bash
cd wvu_knapsack
sh up.sc.local.sh
```

This will:
1. Ensure Ruby 3.3.0 is active (if using rbenv)
2. Start traefik proxy for local HTTPS
3. Build and start web + worker containers
4. Output logs location

Access the app at: `https://wvu-knapsack.localhost.direct/`

### Ruby Version Management

**Using Stack Car with your current Ruby:**

When upgrading your system Ruby version, you'll need to reinstall Stack Car in the new version:

```bash
gem install stack_car
```

This is simpler than managing a `.ruby-version` file across the repo, and Stack Car itself doesn't require 3.3.0—it works with any Ruby 3.x version.

**With rbenv:**
```bash
# After upgrading your rbenv default Ruby version
rbenv rehash
gem install stack_car
sh up.sc.local.sh
```

**Without rbenv:**
- Ensure your current Ruby is 3.x
- `gem install stack_car`
- `sh up.sc.local.sh`

### Quick Restarts

After code changes:
```bash
# Full rebuild (gem/knapsack changes)
sh up.sc.local.sh

# Quick restart (no rebuild)
sc up -d
sc logs web -f
```

---

## Testing

### Local Testing (Stack Car)
```bash
sh up.sc.local.sh
# Full HTTPS/IIIF support for development feature testing
```

### Production Smoke Test (Local Mac)
```bash
sh up.prod.local.sh
# Validates container images + config (HTTP-only, no infra layer)
# For IIIF/HTTPS feature testing, use hykudev or production
```

### Full Feature Testing
- **hykudev VM** — Full feature validation (nginx provides HTTPS)
- **Production** — Live system validation

---

## Code Style & Standards

- Follow upstream Hyku conventions where applicable
- Customizations should live in the knapsack (never modify `hyrax-webapp/` submodule)
- Use decorators/overrides for Hyku components; prefix comments with `# OVERRIDE Hyku vX — reason`

---

## Git Workflow

1. Create a feature branch: `git checkout -b feature/your-feature`
2. Make changes and commit with clear messages
3. Push to origin and open a pull request
4. Ensure tests pass before merging

---

## Need Help?

- See [README.md](README.md) for project overview
- See [HYKU_BUILD_GUIDE.md](HYKU_BUILD_GUIDE.md) for architectural details
- Check [status.md](agent-tasks/projects/wvulibraries_knapsack/status.md) for current issues and progress
