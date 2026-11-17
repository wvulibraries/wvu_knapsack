# Bulkrax Metadata Separator Splits on Colons AND Semicolons

**Status:** OPEN — configuration fix needed, no code change required  
**Discovered:** 2026-11-17  
**Related projects:** ACDAP (`hydra_acdap_portal_public`), congress archives project

---

## Problem

CSV imports through Bulkrax split metadata fields (subject, keyword, people_represented) on **colons AND semicolons**, when they should only split on **semicolons**. Values containing colons within data (e.g., `"Democratic National Convention  (1936 : Philadelphia, Pa.)"`) get incorrectly broken into separate entries.

## Root Cause

Bulkrax gem default: `DEFAULT_MULTI_VALUE_ELEMENT_SPLIT_ON = /\s*[:;|]\s*/.freeze`

Fields with `"split": true` in Bulkrax field mappings fall back to this regex, treating colons as separators. No local override exists in the WVU Knapsack initializer (`hyrax-webapp/config/initializers/bulkrax.rb`).

## Affected Fields (16 total)

All currently set to `"split": true` — need to change to `"split": ";"`:

| Field | Field | Field | Field |
|-------|-------|-------|-------|
| `subject` | `keyword` | `people_represented` | `creator` |
| `contributor` | `description` | `abstract` | `date_created` |
| `identifier` | `language` | `publisher` | `resource_type` |
| `rights_notes` | `source` | `extent` | `policy_area` |

## Fields Already Correct (no change needed)

These already override with pipe-only: `accessibility_feature`, `degree_discipline`, `degree_grantor`, `degree_level`, `degree_name`, `rights_holder`, `table_of_contents`, `newer_version`, `previous_version`, `alternate_version`, `related_item`, `committee_member`, `education_level`, `library_catalog_identifier`, `oer_size`, `audience`.

## Fix

No code changes needed. In the Bulkrax Field Mappings UI (Settings → Bulkrax Field Mappings), change each affected field from `"split": true` to `"split": ";"`.

This is a per-tenant configuration change — apply to whichever tenant(s) need it (demo, production).

## Verification

1. Re-import a test CSV with known colon-containing values
2. Confirm values are NOT split on colons
3. Confirm semicolons still work as separators
