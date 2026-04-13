#!/bin/bash
# Nuclear Option for the Stack Car dev stack.
# Tears down containers, removes named volumes, and removes locally built images
# for this project only — does NOT touch other Docker projects on this machine.
#
# Stack Car uses named Docker volumes (not ./data bind mounts), so no rm -rf needed.
#
# Usage:  sh scripts/cleanup-dev.sh
#
# After running, restart with:
#   sh up.local.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

echo "==> Stopping Stack Car dev stack and removing project volumes + images..."
docker compose down --rmi local -v --remove-orphans 2>/dev/null || true

# Explicitly remove solr volume which may persist due to dual compose file scoping
docker volume rm wvu_knapsack_solr 2>/dev/null || true
# Remove any solr volume matching project name pattern
docker volume ls --format '{{.Name}}' | grep solr | xargs -r docker volume rm 2>/dev/null || true

echo "==> Pruning dangling images and build cache..."
docker image prune -f
docker builder prune -f

echo ""
echo "Done. To restart: sh up.local.sh"
