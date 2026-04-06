#!/usr/bin/env sh
# Local Stack Car development — builds web + worker without cache, then starts via sc.
# Use this after gem or knapsack code changes to get a clean rebuild.
# For quick restarts where no rebuild is needed, use: sc up -d
#
# Usage:
#   sh up.sc.local.sh
set -e

# Ensure submodule is initialised and up to date.
# git submodule update --init --recursive

# hyrax-webapp/.env.production must exist — can be empty for Stack Car dev.
[ -f hyrax-webapp/.env.production ] || touch hyrax-webapp/.env.production

# Rebuild web and worker images.
# Use --no-cache only when Gemfile or system packages changed (forces full reinstall).
# For code-only changes, omit --no-cache — Docker invalidates the COPY layer automatically.
if [[ "${NOCACHE:-}" == "1" ]]; then
  docker compose build --no-cache web worker solr
else
  docker compose build web worker solr
fi

# Proxy must be up before web and worker, otherwise they won't be able to connect to it.
sc proxy up

# --- Ollama model bootstrap ---
# Start the Ollama container on its own first so we can pull the model weights
# before the worker starts trying to call the API.
# Model weights are persisted in the 'ollama' named Docker volume so this is
# only a download on the first run; subsequent starts skip straight to the
# health check.
echo ""
echo "Starting Ollama and pulling model weights..."
docker compose up -d ollama

# Wait until the Ollama HTTP API is responding — up to 60 s.
OLLAMA_MODEL="${OLLAMA_MODEL:-moondream}"
echo "Waiting for Ollama API to be ready..."
for i in $(seq 1 30); do
  if docker compose exec -T ollama ollama list > /dev/null 2>&1; then
    echo "Ollama is ready."
    break
  fi
  [ "$i" -eq 30 ] && { echo "ERROR: Ollama did not become ready in 60 s."; exit 1; }
  sleep 2
done

# Pull the model. 'ollama pull' is idempotent — if the weights are already in
# ./ollama_data it just verifies the manifest and exits immediately.
echo "Pulling model: ${OLLAMA_MODEL}"
docker compose exec -T ollama ollama pull "${OLLAMA_MODEL}"
echo "Model ready: ${OLLAMA_MODEL}"
# ------------------------------

# Bring up the full stack in detached mode.
sc up -d

# Ensure JS dependencies are installed — required for the Universal Viewer and
# other Webpacker assets. The node_modules volume persists across restarts so
# this is fast after the first run.
# Wait for the web container to be running before exec-ing into it.
echo ""
echo "Waiting for web container to be running..."
for i in $(seq 1 30); do
  if docker compose exec -T web echo ok > /dev/null 2>&1; then
    break
  fi
  [ "$i" -eq 30 ] && { echo "WARNING: web container did not start in time — skipping yarn install."; }
  sleep 2
done
echo "Running yarn install..."
docker compose exec -T web yarn install --silent && echo "yarn install complete." || echo "WARNING: yarn install failed — run manually: docker compose exec web yarn install"

echo ""
echo "Stack is starting. Watch web logs:"
echo "  docker compose logs web -f"
echo ""
echo "When web shows 'Listening on http://0.0.0.0:3000' it is ready."
echo ""
echo "AI remediation is enabled (AI_ENABLED=true, model=${OLLAMA_MODEL})."
echo "Watch worker logs for AI_REMEDIATION_FAILURE tags:"
echo "  docker compose logs worker -f | grep -E 'AI_REMEDIATION|RemediateAlt|AiDescription'"
