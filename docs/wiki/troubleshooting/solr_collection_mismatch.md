# Solr Collection Mismatch Architecture

**Category:** Troubleshooting  
**Date Created:** 2026-11-17

## The Observation

- Records visible in Solr (queries show doc count > 0)
- Search results empty (queries return 0 docs)
- **Data is NOT lost**, just indexed to the wrong collection

## The Architecture

```
Indexing Path:
  Hyrax.index_adapter.save(resource: work)
    → Valkyrie::Indexing::Solr::IndexingAdapter
    → SolrEndpoint.connection_options['core'] (determines collection name)
    → Solr client indexes to that collection

Search Path:
  CatalogSearchBuilder.build_query
    → Blacklight.connection_config['url']
    → Solr client queries from that collection
```

## If Collections Don't Match

- **Result:** Indexing writes to one collection (e.g., "uuid"), search queries another (e.g., "hydra-production")
- **Symptom:** Facets load (Solr has docs), but results are empty (query collection is empty)
- **Cause:** SolrEndpoint logic changed between versions (e.g., 7.1.3 → 7.2.0)
- **Fix:** Investigate code diff in SolrEndpoint/Valkyrie path; likely `create_solr_collection_job.rb` or how tenant name is used

## How to Confirm Collection Mismatch

```bash
# 1. Check what collection the tenant endpoint points to
docker compose -f docker-compose.production.yml exec web bin/rails runner \
  "puts Account.first.solr_endpoint.inspect"
# Shows: #<SolrEndpoint ... collection:"???" ...>

# 2. Check Solr doc counts per collection
curl 'http://localhost:8983/solr/uuid/select?q=*:*&rows=0' | jq .response.numFound
curl 'http://localhost:8983/solr/hydra-production/select?q=*:*&rows=0' | jq .response.numFound

# 3. If one collection has docs and the other is empty → collection mismatch confirmed
```

## Key Takeaways

- **Data safety:** Documents aren't lost; a wrong collection is an easy fix
- **Code vs data:** This is NOT a data problem, it's a code logic problem
- **Testing strategy:** Don't clear Solr; fix the code that selects the collection
- **Upgrade impact:** Any upgrade changing SolrEndpoint logic must be tested carefully
