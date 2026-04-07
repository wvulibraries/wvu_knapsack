# TASK: Move alt_text from m3 flexible schema to native Hyrax::FileSet attribute
**Status**: BACKLOG
**Priority**: HIGH
**Type**: refactor
**Created**: 2026-04-06
**Last Updated**: 2026-04-06

---

## Agent Assignment

**Assigned To**: Grok Code Fast 0.25x
**Why This Agent**: Task simplified by upstream discovery — exact code provided, no architectural judgment needed
**Supervision Level**: 🟡 Standard
**Updated**: 2026-04-06 — reassigned from Claude Sonnet after discovering hyrax-webapp already defines alt_text in its own m3 profile; task is now a removal, not an addition

---

## Context

During testing, `alt_text` was added to the m3 flexible metadata profile (`config/metadata_profiles/m3_profile.yaml`) as a quick way to make the attribute available on `Hyrax::FileSet`. This works but is wrong for production — the m3 profile is for user-editable content metadata fields. `alt_text` is an internal AI-generated accessibility field that should be a native attribute on the model, not part of the flexible schema.

The attribute needs to be declared directly on `Hyrax::FileSet` via the Valkyrie attribute DSL so it persists to Fedora/Postgres and is available without flexible schema loading.

**Critical architecture facts**:
- App runs `HYRAX_FLEXIBLE=true` — Valkyrie mode
- `Hyrax::FileSet` inherits from `Hyrax::Resource` which inherits from `Valkyrie::Resource`
- Attributes on Valkyrie resources are declared with `attribute :name, Valkyrie::Types::...`
- The knapsack wires into `Hyrax::FileSet` via `app/models/file_set_decorator.rb`
- Do NOT edit `hyrax-webapp/` — use the decorator pattern

---

## Problem Statement

**Current behavior**: `alt_text` is defined in `config/metadata_profiles/m3_profile.yaml` under `Hyrax::FileSet`. This means it is loaded as a flexible metadata field, which is intended for user-facing content metadata, not AI-generated internal fields.

**Expected behavior**: `alt_text` should be declared as a native Valkyrie attribute on `Hyrax::FileSet` via the knapsack decorator, and removed from the m3 profile.

---

## Files Involved

### Primary Files — you will edit these
| File | Purpose | Key Method/Section |
|---|---|---|
| `app/models/file_set_decorator.rb` | Decorates Hyrax::FileSet | Add attribute declaration |
| `config/metadata_profiles/m3_profile.yaml` | Flexible schema | Remove alt_text entry (lines ~1703–1730) |

### Reference Files — read but do not edit
| File | Why You Need It |
|---|---|
| `data/bundle/bundler/gems/hyrax-aced8ad9cd7d/app/models/hyrax/file_set.rb` | Shows existing Valkyrie attribute declarations on FileSet |
| `data/bundle/bundler/gems/hyrax-aced8ad9cd7d/app/models/hyrax/resource.rb` | Shows Hyrax::Resource base class |

---

## Implementation Steps

### Step 1 — Add native attribute to Hyrax::FileSet via decorator

Edit `app/models/file_set_decorator.rb`:

```ruby
# Before
# frozen_string_literal: true
Hyrax::FileSet.include AiMetadataBehavior

# After
# frozen_string_literal: true
Hyrax::FileSet.include AiMetadataBehavior

# Declare alt_text as a native Valkyrie attribute.
# This persists alongside the FileSet in Fedora/Postgres without
# requiring the flexible m3 schema.
Hyrax::FileSet.attribute :alt_text, Valkyrie::Types::Array.of(Valkyrie::Types::String)
```

### Step 2 — Remove alt_text from m3_profile.yaml

In `config/metadata_profiles/m3_profile.yaml`, remove the entire `alt_text:` block (approximately 28 lines at the end of the file starting with `  alt_text:`).

### Step 3 — Verify in Rails console

```bash
docker compose restart web worker
docker compose exec web bundle exec rails console
```
```ruby
AccountElevator.switch!('testing')
fs = Hyrax.query_service.find_by(id: Valkyrie::ID.new('PASTE-ANY-REAL-FILESET-ID'))
puts fs.respond_to?(:alt_text)   # should be true
puts fs.alt_text.inspect          # should be [] or existing value
fs.alt_text = ['Test alt text']
Hyrax.persister.save(resource: fs)
fs2 = Hyrax.query_service.find_by(id: fs.id)
puts fs2.alt_text.inspect         # should be ["Test alt text"]
```

---

## Acceptance Criteria
- [ ] `Hyrax::FileSet.new.respond_to?(:alt_text)` returns `true`
- [ ] `alt_text` persists to and loads from Fedora/Postgres correctly
- [ ] `alt_text` is no longer in `config/metadata_profiles/m3_profile.yaml`
- [ ] No errors on `docker compose restart web worker`
- [ ] `AiDescriptionJob` still saves alt_text correctly after the change

---

## Stop Conditions — escalate to user immediately if:
- `Valkyrie::Types::Array.of(Valkyrie::Types::String)` causes a type error
- Attribute declaration syntax differs for this version of Valkyrie
- Removing from m3 profile causes any boot error

---

## Dependencies
**Blocked by**: none
**Blocks**: `2026-04-06-HIGH-FEATURE-ALT-TEXT-VIEW-WIRING.md`
**Related tasks**: `2026-04-06-MEDIUM-BUG-FIX-VISION-PROMPT-QUALITY.md`

---

## Completion Report
*To be filled in by implementing agent*
