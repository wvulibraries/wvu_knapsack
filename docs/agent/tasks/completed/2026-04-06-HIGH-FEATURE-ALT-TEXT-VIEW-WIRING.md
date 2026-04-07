# TASK: Wire alt_text to img alt attribute in FileSet views
**Status**: BACKLOG
**Priority**: HIGH
**Type**: feature
**Created**: 2026-04-06
**Last Updated**: 2026-04-06

---

## Agent Assignment

**Assigned To**: GPT-4.1 0x
**Why This Agent**: View template edit — straightforward once the file is located, no architectural reasoning needed
**Supervision Level**: 🔴 Watched carefully

> ⚠️ Do NOT edit anything in `hyrax-webapp/` — find the knapsack override view or create one.

---

## Context

The AI alt-text pipeline generates alt text for images and stores it on `Hyrax::FileSet` as `file_set.alt_text` (an array — use `.first`). However, the HTML `<img>` tags in the FileSet show views do not yet read this attribute. The value is saved to the database but never surfaced in the UI, meaning screen readers get no benefit.

This task wires `file_set.alt_text.first` into the appropriate view partial's `alt` attribute.

**Critical architecture facts**:
- `alt_text` is an array attribute — always use `.first` or `.first.to_s`
- Do NOT edit `hyrax-webapp/` views — create a knapsack override in `app/views/`
- Hyku view override pattern: copy the hyrax-webapp partial to the same relative path under `app/views/` in the knapsack

---

## Problem Statement

**Current behavior**: FileSet show page renders `<img alt="">` or `<img alt="[filename]">` — no AI-generated alt text.

**Expected behavior**: `<img alt="[AI generated description]">` using `file_set.alt_text.first.to_s`, falling back to an empty string if blank.

---

## Files Involved

### Step 1 — Find the correct view partial

Run this on the host to find where the img tag renders:
```bash
grep -rn "img.*alt\|image_tag\|alt_text" /Users/tam0013/Documents/git/wvu_knapsack/hyrax-webapp/app/views/ | grep -v ".git" | head -20
grep -rn "img.*alt\|image_tag\|alt_text" /Users/tam0013/Documents/git/wvu_knapsack/app/views/ 2>/dev/null | head -20
```

### Primary Files — you will edit or create these
| File | Purpose |
|---|---|
| `app/views/[path matching hyrax-webapp partial]` | Knapsack view override — create if it doesn't exist |

### Reference Files — read but do not edit
| File | Why You Need It |
|---|---|
| `hyrax-webapp/app/views/[relevant partial]` | Source to copy and override |

---

## Implementation Steps

### Step 1 — Locate the image rendering partial
```bash
grep -rn "image_tag\|<img" /Users/tam0013/Documents/git/wvu_knapsack/hyrax-webapp/app/views/hyrax/file_sets/ 2>/dev/null
grep -rn "image_tag\|<img" /Users/tam0013/Documents/git/wvu_knapsack/hyrax-webapp/app/views/ 2>/dev/null | grep -i "thumb\|show\|media" | head -20
```

### Step 2 — Create knapsack override
Copy the relevant partial from `hyrax-webapp/app/views/[path]` to `app/views/[same path]`.

### Step 3 — Add alt_text to img tag
Find the `image_tag` or `<img` call and add:
```erb
<%# Before %>
<%= image_tag file_set.thumbnail_url %>

<%# After %>
<%= image_tag file_set.thumbnail_url, alt: file_set.try(:alt_text)&.first.to_s %>
```

Use `.try(:alt_text)` defensively in case the attribute isn't loaded.

### Step 4 — Verify in browser
1. Navigate to a work show page with a Tracy image FileSet
2. Inspect the `<img>` element
3. Confirm `alt` attribute contains the AI-generated text

---

## Acceptance Criteria
- [ ] `<img>` tag on FileSet show page has non-empty `alt` attribute for items with alt_text saved
- [ ] Falls back gracefully to `""` when alt_text is blank
- [ ] No errors in web container logs
- [ ] No changes to `hyrax-webapp/` — only `app/views/` in knapsack

---

## Stop Conditions — escalate to user immediately if:
- Cannot find where image rendering happens in views
- The partial requires changes to a controller or helper (not a view-only change)
- Image rendering is done via a Presenter and requires overriding a Ruby class instead

---

## Dependencies
**Blocked by**: `2026-04-06-HIGH-REFACTOR-ALT-TEXT-M3-TO-NATIVE-ATTRIBUTE.md` (alt_text must be a stable attribute first)
**Blocks**: none
**Related tasks**: `2026-04-06-MEDIUM-BUG-FIX-VISION-PROMPT-QUALITY.md`

---

## Completion Report
*To be filled in by implementing agent*
