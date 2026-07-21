#!/usr/bin/env sh
# Local production smoke test — mirrors up.sh but targets docker-compose.local.yml.
# Pulls pre-built arm64 GHCR images; does NOT build locally.
# Use this to validate the production image and config on a Mac before VM deployment.
#
# Usage:
#   sh up.prod.local.sh
#
# Then run one-time setup (idempotent — safe to re-run):
#   docker compose -f docker-compose.local.yml exec web sh /app/samvera/scripts/setup.sh
set -e

# Keep submodule pinned to the commit checked out locally.
# Do not auto-update on each run; this mirrors up.sh behavior and avoids
# unintentionally resetting local hotfixes during smoke tests.
# Run manually only when intentionally updating the submodule:
#   git submodule update --init --recursive

# hyrax-webapp/.env.production must exist — can be empty, real vars come from
# the knapsack root .env.production via the x-app anchor's env_file.
[ -f hyrax-webapp/.env.production ] || touch hyrax-webapp/.env.production

# Pre-create bind-mount directories so Docker doesn't create them as root:root.
# chmod 777 on bundle is required on Mac — chown to uid 1001 isn't effective here
# (the fix_permissions service in docker-compose.local.yml also handles this, but
# creating the directory first avoids Docker creating it as root in the first place).
#
# NOTE: If data/ is a symlink (production VM with mounted volume), do NOT use mkdir -p
# because it will resolve the symlink and convert it to a real directory.
# Instead, create directories only if data/ is a real directory.
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
  chmod 777 ./data/bundle ./data/node_modules ./data/assets ./data/cache
elif [ -L ./data ]; then
  # data/ is a symlink (production with mounted volume) — assume target already exists
  # Do NOT run mkdir -p as it would resolve and break the symlink
  echo "✓ data/ is symlink ($(readlink ./data)) — skipping mkdir to preserve symlink"
else
  # data/ doesn't exist — create it as real directory
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
  chmod 777 ./data/bundle ./data/node_modules ./data/assets ./data/cache
fi

docker compose -f docker-compose.local.yml up -d

echo ""
echo "Stack is starting. Watch progress:"
echo "  docker compose -f docker-compose.local.yml logs -f initialize_app"
echo ""
echo "When initialize_app completes, run one-time setup:"
echo "  docker compose -f docker-compose.local.yml exec web sh /app/samvera/scripts/setup.sh"
