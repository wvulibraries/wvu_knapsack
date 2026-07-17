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
  ./data/logs/solr
chmod 777 ./data/bundle ./data/node_modules ./data/assets ./data/cache

docker compose -f docker-compose.local.yml up -d

echo ""
echo "Stack is starting. Watch progress:"
echo "  docker compose -f docker-compose.local.yml logs -f initialize_app"
echo ""
echo "When initialize_app completes, run one-time setup:"
echo "  docker compose -f docker-compose.local.yml exec web sh /app/samvera/scripts/setup.sh"
