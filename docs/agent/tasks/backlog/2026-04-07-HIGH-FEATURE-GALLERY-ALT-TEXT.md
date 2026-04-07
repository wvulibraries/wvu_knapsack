# TASK: Add alt_text support to catalog gallery/list view thumbnails
**Status**: BACKLOG
**Priority**: HIGH
**Type**: feature
**Created**: 2026-04-07
**Last Updated**: 2026-04-07

---

## Agent Assignment

**Assigned To**: GPT-4.1 0x
**Why This Agent**: View override is single-file edit with exact pattern from Task 3
**Supervision Level**: 🟢 Low
**Updated**: 2026-04-07

---

## Context

The catalog gallery and list views display thumbnails using `thumbnail_alt_text_for(document)`, which does not access the FileSet's `alt_text` attribute. This results in missing alt text for screen readers in gallery views, even though FileSet show pages have alt text.

Updated Hyku has specific examples of alt_text setup in profiles, and this is working on prod VM. We need knapsack overrides to ensure gallery thumbnails use `file_set.alt_text.first.presence || file_set.title.first`.

---

## Problem Statement

**Current behavior**: Gallery/list thumbnails have generic or missing alt text from `thumbnail_alt_text_for(document)`.

**Expected behavior**: Gallery/list thumbnails display AI-generated alt text from `file_set.alt_text.first`, falling back to `file_set.title.first`.

---

## Files Involved

### Primary Files — you will edit these
| File | Purpose | Key Method/Section |
|---|---|---|
| `app/views/catalog/_thumbnail_list_default.html.erb` | Override gallery list thumbnail | Replace `thumbnail_alt_text_for(document)` with custom alt logic |
| `app/views/catalog/_document_gallery.html.erb` | Override gallery view (if needed) | Ensure thumbnails use alt_text |

### Reference Files — read but do not edit
| File | Purpose |
|---|---|
| `hyrax-webapp/app/views/catalog/_thumbnail_list_default.html.erb` | Upstream partial to override |
| `hyrax-webapp/app/views/catalog/_document_gallery.html.erb` | Upstream gallery partial |
| `app/views/hyrax/file_sets/media_display/_image.html.erb` | Reference for alt_text pattern |

---

## Implementation Steps

1. **Read upstream partials** — Understand current `thumbnail_alt_text_for(document)` usage
2. **Create knapsack overrides** — Copy upstream files to `app/views/catalog/` and modify alt logic
3. **Implement alt_text access** — For FileSet documents, load the FileSet and use `file_set.alt_text.first.presence || file_set.title.first`
4. **Test gallery views** — Restart web and verify thumbnails have alt text in both list and gallery views
5. **Commit changes**

### Key Implementation Details

In the override partials, replace:
```erb
<%= document_presenter(document)&.thumbnail&.thumbnail_tag({ alt: thumbnail_alt_text_for(document) }, additional_options ) %>
```

With:
```erb
<% if document.hydra_model == Hyrax::FileSet || document.hydra_model < Hyrax::FileSet %>
  <% file_set = Hyrax.query_service.find_by(id: Valkyrie::ID.new(document.id)) rescue nil %>
  <% alt_text = file_set&.alt_text&.first.presence || document.title&.first %>
<% else %>
  <% alt_text = thumbnail_alt_text_for(document) %>
<% end %>
<%= document_presenter(document)&.thumbnail&.thumbnail_tag({ alt: alt_text }, additional_options ) %>
```

This ensures FileSets get alt_text, while other models (collections) keep existing behavior.

---

## Acceptance Criteria

- Gallery view thumbnails have alt text from `file_set.alt_text` or fallback to title
- List view thumbnails have alt text from `file_set.alt_text` or fallback to title
- No impact on collection thumbnails (they keep `thumbnail_alt_text_for`)
- Web service restarts without errors
- Visually verified in browser gallery/list views

---

## Commit Message

feat: add alt_text support to catalog gallery/list view thumbnails — use file_set.alt_text for FileSet thumbnails, fallback to title. See 2026-04-07-HIGH-FEATURE-GALLERY-ALT-TEXT.md