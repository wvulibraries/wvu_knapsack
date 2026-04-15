#!/usr/bin/env sh
# Local Stack Car development — builds web + worker without cache, then starts via sc.
# Use this after gem or knapsack code changes to get a clean rebuild.
# For quick restarts where no rebuild is needed, use: sc up -d
#
# Usage:
#   sh up.sc.local.sh

sc proxy up

set -e

# Ensure submodule is initialised and up to date.
# git submodule update --init --recursive

# hyrax-webapp/.env.production must exist — can be empty for Stack Car dev.
[ -f hyrax-webapp/.env.production ] || touch hyrax-webapp/.env.production

# Rebuild web and worker from scratch, then bring up the full stack.
docker compose build --no-cache web worker
sc up -d

echo ""
echo "Stack is starting. Watch web logs:"
echo "  sc logs web -f"
echo ""
echo "When web shows 'Listening on http://0.0.0.0:3000' it is ready."
