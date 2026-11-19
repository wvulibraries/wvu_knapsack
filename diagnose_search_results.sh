#!/bin/bash
# Diagnostic Script for Hyku 7.2.0 Search Results Display Issue
# Run on hykudev to diagnose why facets load but results don't display
# 
# Usage: bash diagnose_search_results.sh
# Output: Saves results to diagnostic_results_TIMESTAMP.txt

TIMESTAMP=$(date +%s)
OUTPUT_FILE="diagnostic_results_${TIMESTAMP}.txt"

echo "=== HYKU 7.2.0 SEARCH RESULTS DIAGNOSTIC ==="
echo "Starting: $(date)" | tee "$OUTPUT_FILE"
echo "" | tee -a "$OUTPUT_FILE"

# ============================================================================
# PHASE 1: SOLR STATE VERIFICATION
# ============================================================================

echo "=== PHASE 1: SOLR STATE VERIFICATION ===" | tee -a "$OUTPUT_FILE"
echo "" | tee -a "$OUTPUT_FILE"

echo "Task 1.1 — Solr Collection Status" | tee -a "$OUTPUT_FILE"
echo "Command: docker compose exec -T solr solr status" | tee -a "$OUTPUT_FILE"
docker compose exec -T solr solr status 2>&1 | tee -a "$OUTPUT_FILE"
echo "" | tee -a "$OUTPUT_FILE"

echo "Task 1.2 — Solr Document Count" | tee -a "$OUTPUT_FILE"
echo "Command: curl -s http://localhost:8983/solr/hydra-production/select?q=*:*" | tee -a "$OUTPUT_FILE"
curl -s "http://localhost:8983/solr/hydra-production/select?q=*:*" | jq '.response.numFound' 2>&1 | tee -a "$OUTPUT_FILE"
echo "" | tee -a "$OUTPUT_FILE"

echo "Task 1.3 — Verify Solr Reachability from Web Container" | tee -a "$OUTPUT_FILE"
echo "Command: docker compose exec web curl -s http://solr:8983/solr/hydra-production/select?q=*:*&rows=1" | tee -a "$OUTPUT_FILE"
docker compose exec -T web curl -s "http://solr:8983/solr/hydra-production/select?q=*:*&rows=1" 2>&1 | jq '.response.docs[0]' | tee -a "$OUTPUT_FILE"
echo "" | tee -a "$OUTPUT_FILE"

# ============================================================================
# PHASE 2: SCHEMA COMPATIBILITY CHECK
# ============================================================================

echo "=== PHASE 2: SCHEMA COMPATIBILITY CHECK ===" | tee -a "$OUTPUT_FILE"
echo "" | tee -a "$OUTPUT_FILE"

echo "Task 2.1 — Solr Field List" | tee -a "$OUTPUT_FILE"
echo "Command: curl -s http://localhost:8983/solr/hydra-production/schema/fields | jq '.fields | map(.name) | sort'" | tee -a "$OUTPUT_FILE"
curl -s "http://localhost:8983/solr/hydra-production/schema/fields" 2>&1 | jq '.fields | map(.name) | sort' | tee -a "$OUTPUT_FILE"
echo "" | tee -a "$OUTPUT_FILE"

echo "Task 2.2 — Raw Solr Query Test (5 documents)" | tee -a "$OUTPUT_FILE"
echo "Command: curl -s http://localhost:8983/solr/hydra-production/select?q=*:*&rows=5&wt=json | jq '.response.docs'" | tee -a "$OUTPUT_FILE"
curl -s "http://localhost:8983/solr/hydra-production/select?q=*:*&rows=5&wt=json" 2>&1 | jq '.response.docs' | tee -a "$OUTPUT_FILE"
echo "" | tee -a "$OUTPUT_FILE"

# ============================================================================
# PHASE 3: RAILS SEARCH LAYER
# ============================================================================

echo "=== PHASE 3: RAILS SEARCH LAYER ===" | tee -a "$OUTPUT_FILE"
echo "" | tee -a "$OUTPUT_FILE"

echo "Task 3.1 — Rails Console Search Test" | tee -a "$OUTPUT_FILE"
echo "Command: docker compose exec web bundle exec rails console (interactive)" | tee -a "$OUTPUT_FILE"
echo "Running: results = Blacklight.repository.search({}); puts results.inspect" | tee -a "$OUTPUT_FILE"
docker compose exec -T web bash -c 'bundle exec rails runner "results = Blacklight.repository.search({}); puts \"Result count: #{results.documents.count}\"; puts \"Total found: #{results.total}\"; puts \"First doc: #{results.documents.first.inspect}\"" 2>&1' | tee -a "$OUTPUT_FILE"
echo "" | tee -a "$OUTPUT_FILE"

echo "Task 3.2 — CatalogController Config" | tee -a "$OUTPUT_FILE"
echo "Looking for search_builder_class configuration..." | tee -a "$OUTPUT_FILE"
docker compose exec -T web grep -n "search_builder_class\|solr_path" app/controllers/catalog_controller.rb 2>&1 | tee -a "$OUTPUT_FILE"
docker compose exec -T web grep -n "search_builder_class\|solr_path" config/initializers/catalog_controller_decorator.rb 2>&1 | tee -a "$OUTPUT_FILE"
echo "" | tee -a "$OUTPUT_FILE"

# ============================================================================
# PHASE 4: VIEW LAYER & ENVIRONMENT INFO
# ============================================================================

echo "=== PHASE 4: VIEW LAYER & ENVIRONMENT INFO ===" | tee -a "$OUTPUT_FILE"
echo "" | tee -a "$OUTPUT_FILE"

echo "Task 4.1 — Git Status & Branch" | tee -a "$OUTPUT_FILE"
docker compose exec -T web bash -c 'cd /app/samvera && git log -1 --oneline && git branch -v' 2>&1 | tee -a "$OUTPUT_FILE"
echo "" | tee -a "$OUTPUT_FILE"

echo "Task 4.2 — Blacklight Configuration" | tee -a "$OUTPUT_FILE"
docker compose exec -T web bash -c 'bundle exec rails runner "config = CatalogController.blacklight_config; puts \"Search Path: #{config.search_path}\"; puts \"Solr Path: #{config.solr_path}\"" 2>&1' | tee -a "$OUTPUT_FILE"
echo "" | tee -a "$OUTPUT_FILE"

echo "Task 4.3 — View Template Check" | tee -a "$OUTPUT_FILE"
echo "Looking for catalog/index view..." | tee -a "$OUTPUT_FILE"
docker compose exec -T web bash -c 'find app/views -name "*index*" -o -name "*catalog*" | head -10' 2>&1 | tee -a "$OUTPUT_FILE"
echo "" | tee -a "$OUTPUT_FILE"

# ============================================================================
# PHASE 5: FACET CONFIGURATION
# ============================================================================

echo "=== PHASE 5: FACET CONFIGURATION ===" | tee -a "$OUTPUT_FILE"
echo "" | tee -a "$OUTPUT_FILE"

echo "Task 5.1 — Registered Facets" | tee -a "$OUTPUT_FILE"
docker compose exec -T web bash -c 'bundle exec rails runner "config = CatalogController.blacklight_config; puts config.facet_fields.inspect" 2>&1' | head -50 | tee -a "$OUTPUT_FILE"
echo "" | tee -a "$OUTPUT_FILE"

echo "Task 5.2 — Catalog Search Builder" | tee -a "$OUTPUT_FILE"
docker compose exec -T web bash -c 'bundle exec rails runner "builder = CatalogController.new.search_builder_class.new(CatalogController.new.blacklight_config); puts builder.inspect" 2>&1' | head -20 | tee -a "$OUTPUT_FILE"
echo "" | tee -a "$OUTPUT_FILE"

# ============================================================================
# SUMMARY
# ============================================================================

echo "=== DIAGNOSTIC COMPLETE ===" | tee -a "$OUTPUT_FILE"
echo "Output saved to: $OUTPUT_FILE" | tee -a "$OUTPUT_FILE"
echo "Timestamp: $(date)" | tee -a "$OUTPUT_FILE"

echo ""
echo "✓ Diagnostic complete. Results saved to: $OUTPUT_FILE"
echo "Transfer this file to agent-tasks for analysis."
