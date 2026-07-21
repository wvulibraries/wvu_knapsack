#!/usr/bin/env sh
set -e

# Pull latest knapsack code before bringing up containers.
git pull


# ---
# NOTE: The following submodule update command is commented out intentionally.
# Running 'git submodule update --init --recursive' here would update the hyrax-webapp submodule
# every time up.sh runs, which is NOT desired. The submodule should remain locked to the commit
# specified in the parent repo, to avoid unexpected changes. Only run this manually after a fresh clone
# or when intentionally updating the submodule:
#   git submodule update --init --recursive
#   cd hyrax-webapp && git fetch --tags && git checkout <desired-tag-or-branch>
# ---

# hyrax-webapp/.env.production must exist because the submodule's docker-compose
# declares it in env_file. It can be empty — real vars come from .env.production
# at the knapsack root. The submodule's .gitignore already covers .env.* so this
# file is invisible to submodule git tracking.
[ -f hyrax-webapp/.env.production ] || touch hyrax-webapp/.env.production


# Pre-create bind-mount directories with symlink protection.
# If data/ is a symlink (production VM with mounted volume), preserve it.
# Otherwise, create directories if data/ is a real directory or doesn't exist yet.
#
# Note: mkdir -p ./data/bundle on a symlink resolves the symlink and converts it
# to a real directory, breaking the mounted volume binding. This is the fix for
# the symlink deletion issue where data/ would become a real dir after ./up.sh.
if [ -d ./data ] && [ ! -L ./data ]; then
  # data/ exists and is NOT a symlink — safe to create subdirectories
  mkdir -p \
    ./data/bundle \
    ./data/node_modules \
    ./data/assets \
    ./data/cache \
    ./data/uploads \
    ./data/db \
    ./data/solr \
    ./data/zoo \
    ./data/zk \
    ./data/fcrepo \
    ./data/redis \
    ./data/logs/solr \
    ./data/logs/rails
  chown -R 1001:101 ./data/bundle ./data/node_modules ./data/assets ./data/cache ./data/logs
elif [ -L ./data ]; then
  # data/ is a symlink (production with mounted volume) — assume target already exists
  # Do NOT run mkdir -p as it would resolve and break the symlink
  echo "✓ data/ is symlink ($(readlink ./data)) — preserving for mounted volume"
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
