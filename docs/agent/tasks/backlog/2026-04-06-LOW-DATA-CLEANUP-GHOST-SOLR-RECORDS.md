# TASK: Clean up ghost Solr records from failed Bulkrax imports
**Status**: BACKLOG
**Priority**: LOW
**Type**: data
**Created**: 2026-04-06
**Last Updated**: 2026-04-06

---

## Agent Assignment

**Assigned To**: GPT-4.1 0x
**Why This Agent**: Console script execution — explicit commands provided, no architectural reasoning needed
**Supervision Level**: 🔴 Watched carefully — destructive operation, verify before deleting

---

## Context

During early development testing, a Bulkrax import was run with an incorrect file path. This created ~130 FileSet records in Solr but **not** in Fedora. These are "ghost" records — they appear in the UI (Solr-rendered) but cannot be loaded from Fedora, causing `ObjectNotFoundError` when Rails tries to load them.

These ghost records only exist in the **development tenant** (`testing`). They are harmless in production (which was never affected) but cause confusing errors and inflated record counts in the dev stack.

**This task is development-only cleanup. Do not run in production.**

---

## Problem Statement

**Current behavior**: Solr contains FileSet records whose IDs do not exist in Fedora/Postgres. Any attempt to `find_by` these IDs raises `Valkyrie::Persistence::ObjectNotFoundError`.

**Expected behavior**: Solr only contains records that exist in the persistence layer.

---

## Files Involved

No files to edit — Rails console commands only.

---

## Implementation Steps

### Step 1 — Identify ghost record IDs
```bash
docker compose exec web bundle exec rails console
```
```ruby
Pry.config.pager = false
AccountElevator.switch!('testing')

conn = Hyrax::SolrService.instance.conn
resp = conn.get('select', params: { q: 'has_model_ssim:FileSet', rows: 500, fl: 'id' })
all_ids = resp['response']['docs'].map { |r| r['id'] }
puts "Total Solr FileSets: #{all_ids.size}"

ghost_ids = all_ids.select do |id|
  Hyrax.query_service.find_by(id: Valkyrie::ID.new(id))
  false
rescue Valkyrie::Persistence::ObjectNotFoundError
  true
end
puts "Ghost IDs found: #{ghost_ids.size}"
puts ghost_ids.join("\n")
```

### Step 2 — Review before deleting
Confirm the ghost count is expected (~130) and the real record IDs are NOT in the ghost list.

### Step 3 — Delete ghost records from Solr
```ruby
ghost_ids.each do |id|
  conn.delete_by_id(id)
  print '.'
end
conn.commit
puts "\nDeleted #{ghost_ids.size} ghost records and committed."
```

### Step 4 — Verify
```ruby
resp2 = conn.get('select', params: { q: 'has_model_ssim:FileSet', rows: 500, fl: 'id' })
puts "Remaining Solr FileSets: #{resp2['response']['docs'].size}"
```

---

## Acceptance Criteria
- [ ] `ghost_ids.size` matches expected count before deletion
- [ ] Real FileSet IDs are NOT in the ghost list (sample check 5 real IDs before deleting)
- [ ] After deletion, all remaining Solr FileSets load cleanly from Fedora/Postgres
- [ ] No errors on `find_all_of_model` in the console after cleanup

---

## Stop Conditions — escalate to user immediately if:
- Ghost count is 0 — stack may have been rebuilt and ghosts already gone
- Ghost count is much higher than ~130 — may indicate a different problem
- Real records appear in the ghost list — STOP, do not delete, escalate

---

## Dependencies
**Blocked by**: none (dev-only cleanup)
**Blocks**: nothing
**Related tasks**: none

---

## Completion Report
*To be filled in by implementing agent*
