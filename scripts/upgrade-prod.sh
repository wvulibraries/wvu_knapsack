#!/bin/bash
# Safe production upgrade script for VM deployment.
# Preserves all data (DB, Solr, Fedora, uploads, Redis, ZooKeeper) while
# cleaning gem cache and rebuilding images with fresh dependencies.
#
# This script is designed for upgrading to a new Hyku version (e.g., 7.2.0)
# on the production VM (hykudev) WITHOUT data loss.
#
# Usage:
#   sh scripts/upgrade-prod.sh                   # upgrade on current branch
#   sh scripts/upgrade-prod.sh feature/hyku-v7.2.0-upgrade    # switch branch then upgrade
#
# What it does:
#   1. Optionally switches to a specified git branch
#   2. Stops all running services (preserves Docker volumes)
#   3. Removes stale Docker images and gem cache (keeps data volumes intact)
#   4. Rebuilds images with fresh gem dependencies
#   5. Restarts services and waits for readiness
#   6. Verifies data persistence (sample record counts)
#
# Safety:
#   - Data volumes are NEVER removed (--volumes flag NOT used)
#   - ./data bind mount is preserved in its entirety
#   - All database, search index, and file storage persist across upgrade
#   - Easily rollback by reverting git branch and re-running this script

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

BRANCH_TO_CHECKOUT="${1:-}"
COMPOSE_FILE="docker-compose.production.yml"
ENV_FILE_ARGS="--env-file .env.production"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}WVU Knapsack Production Upgrade Script${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Step 1: Optional branch checkout
if [ -n "$BRANCH_TO_CHECKOUT" ]; then
  echo -e "${YELLOW}Step 1: Switching to branch: $BRANCH_TO_CHECKOUT${NC}"
  git fetch origin
  git checkout "$BRANCH_TO_CHECKOUT"
  git submodule update --init --recursive
  echo -e "${GREEN}✓ Branch switched and submodules updated${NC}"
  echo ""
else
  echo -e "${YELLOW}Step 1: Staying on current branch${NC}"
  CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
  echo "  Current branch: $CURRENT_BRANCH"
  echo ""
fi

# Step 2: Pre-upgrade data verification
echo -e "${YELLOW}Step 2: Pre-upgrade data verification${NC}"

# Count records in Postgres (admin tenant by default)
RECORD_COUNT_BEFORE=$(docker compose $ENV_FILE_ARGS -f "$COMPOSE_FILE" exec -T db psql -U postgres -h localhost -d hyku_production -t -c "SELECT COUNT(*) FROM generic_works;" 2>/dev/null || echo "unable-to-count")
if [ "$RECORD_COUNT_BEFORE" != "unable-to-count" ]; then
  echo "  Records in DB (generic_works): $RECORD_COUNT_BEFORE"
else
  echo "  Warning: Could not count pre-upgrade records (services may not be running yet)"
fi
echo ""

# Step 3: Graceful shutdown
echo -e "${YELLOW}Step 3: Stopping services gracefully${NC}"
echo "  Stopping containers without removing volumes..."
# shellcheck disable=SC2086
docker compose $ENV_FILE_ARGS -f "$COMPOSE_FILE" down --remove-orphans 2>/dev/null || true
echo -e "${GREEN}✓ All services stopped${NC}"
echo ""

# Step 4: Clean gem cache and stale Docker images
echo -e "${YELLOW}Step 4: Cleaning stale images and gem cache${NC}"
echo "  Removing locally built images (keeps ./data intact)..."
# Remove only locally built images, not base images
docker compose $ENV_FILE_ARGS -f "$COMPOSE_FILE" down --rmi local 2>/dev/null || true
echo "  Pruning dangling images..."
docker image prune -f > /dev/null
echo "  Pruning build cache..."
docker builder prune -f > /dev/null

# Clean gem cache directory (but preserve ./data structure)
if [ -d ./data/bundle ]; then
  echo "  Clearing gem cache in ./data/bundle..."
  rm -rf ./data/bundle/*
  echo -e "${GREEN}✓ Gem cache cleared${NC}"
else
  echo "  ./data/bundle not found (will be created on rebuild)"
fi
echo ""

# Step 5: Rebuild images with fresh gems
echo -e "${YELLOW}Step 5: Rebuilding images with fresh gem dependencies${NC}"
echo "  Building web and worker images..."
docker compose $ENV_FILE_ARGS -f "$COMPOSE_FILE" build --no-cache web worker 2>&1 | tail -20
echo -e "${GREEN}✓ Images rebuilt${NC}"
echo ""

# Step 6: Start services
echo -e "${YELLOW}Step 6: Starting services${NC}"
echo "  Bringing up all services..."
# shellcheck disable=SC2086
docker compose $ENV_FILE_ARGS -f "$COMPOSE_FILE" up -d
echo "  Waiting for services to be ready (this may take several minutes)..."
sleep 10

# Wait for web service to be healthy
MAX_RETRIES=60
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  if docker compose $ENV_FILE_ARGS -f "$COMPOSE_FILE" exec -T web curl -s http://localhost:3000/health > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Web service is responding${NC}"
    break
  fi
  RETRY_COUNT=$((RETRY_COUNT + 1))
  if [ $((RETRY_COUNT % 10)) -eq 0 ]; then
    echo "  Still waiting... ($RETRY_COUNT/$MAX_RETRIES)"
  fi
  sleep 1
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
  echo -e "${RED}✗ Web service did not respond after $MAX_RETRIES seconds${NC}"
  echo "  Check logs with: docker compose -f $COMPOSE_FILE logs -f web"
  exit 1
fi
echo ""

# Step 7: Post-upgrade data verification
echo -e "${YELLOW}Step 7: Post-upgrade data verification${NC}"

RECORD_COUNT_AFTER=$(docker compose $ENV_FILE_ARGS -f "$COMPOSE_FILE" exec -T db psql -U postgres -h localhost -d hyku_production -t -c "SELECT COUNT(*) FROM generic_works;" 2>/dev/null || echo "unable-to-count")
if [ "$RECORD_COUNT_AFTER" != "unable-to-count" ]; then
  echo "  Records in DB (generic_works): $RECORD_COUNT_AFTER"
  if [ "$RECORD_COUNT_BEFORE" != "unable-to-count" ]; then
    if [ "$RECORD_COUNT_BEFORE" -eq "$RECORD_COUNT_AFTER" ]; then
      echo -e "${GREEN}  ✓ Record count preserved!${NC}"
    else
      echo -e "${YELLOW}  ⚠ Warning: Record count changed ($RECORD_COUNT_BEFORE -> $RECORD_COUNT_AFTER)${NC}"
    fi
  fi
else
  echo "  Warning: Could not count post-upgrade records"
fi

# Check if Solr is responding
if docker compose $ENV_FILE_ARGS -f "$COMPOSE_FILE" exec -T web curl -s http://solr:8983/solr/admin/cores > /dev/null 2>&1; then
  echo -e "${GREEN}  ✓ Solr is responding${NC}"
else
  echo -e "${YELLOW}  ⚠ Solr may still be starting up${NC}"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✓ Upgrade complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Next steps:"
echo "  1. Verify the app is running: docker compose -f $COMPOSE_FILE logs -f web"
echo "  2. Test the catalog: Visit https://hykudev.lib.wvu.edu/catalog"
echo "  3. Test imports: Run a small test import to verify data handling"
echo "  4. Monitor for errors: docker compose -f $COMPOSE_FILE logs -f"
echo ""
echo "If you need to rollback:"
echo "  1. git checkout <previous-branch>"
echo "  2. sh scripts/upgrade-prod.sh"
echo ""
