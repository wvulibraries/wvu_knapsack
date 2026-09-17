#!/usr/bin/env sh
set -e

# Pull latest knapsack code before bringing up containers.
# Use --rebase to handle divergent branches (local VM commits vs. remote).
# This is safer than merge on a production VM — replays local commits on top of remote.
git pull --rebase

# After git pull --rebase, if there are submodule conflicts (e.g., when VM has local commits),
# resolve with: git add hyrax-webapp && git rebase --continue
#
# Submodule update happens automatically after pull — git reads .gitmodules and checks out
# the commit specified in the parent repo. No manual update command needed.
#
# To INTENTIONALLY UPDATE the submodule to a newer version (e.g., security patches):
#
# Option 1 — Update to remote branch HEAD (locally, then push):
#   cd hyrax-webapp && git fetch origin && git checkout v7.1.3  # or main
#   cd .. && git add hyrax-webapp && git commit -m "update to v7.1.3"
#   git push
#   # Then on VM: git pull --rebase && sh up.sh
#
# Option 2 — Update to remote branch HEAD without local commits (locally only):
#   git submodule update --remote  # check out remote's HEAD
#   git add hyrax-webapp && git commit -m "update to latest"
#   git push
# ---

# hyrax-webapp/.env.production must exist because the submodule's docker-compose
# declares it in env_file. It can be empty — real vars come from .env.production
# at the knapsack root. The submodule's .gitignore already covers .env.* so this
# file is invisible to submodule git tracking.
[ -f hyrax-webapp/.env.production ] || touch hyrax-webapp/.env.production


# Directories managed by this script. Any that are symlinks will be skipped.
MANAGED_DIRS="
bundle
node_modules
assets
cache
db
solr
zoo
zk
fcrepo
redis
logs/solr
logs/rails
"

# If data/ is a symlink, operate on its target.
if [ -L ./data ]; then
    echo "✓ data/ is symlink ($(readlink ./data)) — preserving for mounted volume"
    DATA_ROOT="$(readlink ./data)"
else
    DATA_ROOT="./data"
fi

# Create directories only if they are not symlinks.
if [ -d "$DATA_ROOT" ]; then
    for d in $MANAGED_DIRS; do
        if [ -L "$DATA_ROOT/$d" ]; then
            echo "✓ skipping symlink: $DATA_ROOT/$d"
        else
            mkdir -p "$DATA_ROOT/$d"
        fi
    done

    chown -R 1001:101 \
        "$DATA_ROOT/bundle" \
        "$DATA_ROOT/node_modules" \
        "$DATA_ROOT/assets" \
        "$DATA_ROOT/cache" \
        "$DATA_ROOT/logs/rails" 2>/dev/null || true
else
    echo "⚠ data directory '$DATA_ROOT' not found"
fi


# Remove broken initializer from hyrax-webapp submodule if present.
# disable_solr.rb has a syntax error that aborts assets:precompile, and
# we do not want Solr disabled in production regardless.
rm -f ./hyrax-webapp/config/initializers/disable_solr.rb


# ---
# BuildKit Configuration — Phase 2 Build Optimization
# Enables Docker BuildKit for parallel layer execution (~3-5 min additional savings)
# DOCKER_BUILDKIT=1: Enable BuildKit backend (parallel builds, better caching)
# DOCKER_BUILDKIT_PROGRESS=plain: Clear output without animation (easier debugging)
# BUILDKIT_STEP_LOG_MAX_SIZE=10000000: Increase log buffer to prevent truncation (~10MB)
# ---
export DOCKER_BUILDKIT=1
export DOCKER_BUILDKIT_PROGRESS=plain
export BUILDKIT_STEP_LOG_MAX_SIZE=10000000

docker compose --env-file .env.production -f docker-compose.production.yml up -d
