# Task: Add Bulkrax Thumbnail Auto-Resize on Import

**Project:** ACDA Portal (hydra_acda_portal_public)  
**GitHub Issue:** [#92](https://github.com/wvulibraries/hydra_acda_portal_public/issues/92)  
**Status:** Todo  
**Assigned:** trmccormick  
**Estimated Effort:** 4-6 hours (research + implementation + testing)

## Objective
Implement automatic thumbnail image resizing in Bulkrax importer to enforce standard thumbnail size constraints (~200px on longest side) when uploading items with edm:preview field thumbnails.

## Background
Users uploading content to ACDA Portal can specify large thumbnail images in the `edm:preview` field. When these images exceed standard thumbnail size (~200px restraint on longest side), they render at full size, breaking the CSS layout on the item browser page.

**Current State:**
- ✅ Issue identified and visible on dev: https://congressarchivesdev.lib.wvu.edu
- ✅ Problem occurs during Bulkrax import process
- ✅ Screenshot of layout breakage available in GitHub issue #92

**Desired Behavior:**
- Bulkrax should automatically resize oversized thumbnails to standard size during import
- Images smaller than 200px (longest side) remain unchanged
- CSS formatting remains intact across all screen sizes

## Problem Analysis

**Impact:** Visual layout breaks when thumbnails exceed expected dimensions  
**Scope:** Affects all items imported with large edm:preview images  
**Related:** Hyku/Hyrax standard image handling, Bulkrax import pipeline  

## Implementation Approach

### Option 1: Add Resize Logic to Thumbnail Processing Job (Preferred)
ACDA Portal has custom import code that uses background jobs for thumbnail processing. Add size-awareness to existing job:

1. **Identify ACDA Portal's custom import code:**
   - Locate ACDA Portal's custom importer class/module that integrates with Bulkrax
   - Find the background job that handles thumbnail processing (likely triggered on item creation)
   - Job already handles: PDF → thumbnail, missing thumbnail generation, thumbnail assignment, etc.

2. **Add resize constraint to the job:**
   - When processing edm:preview field thumbnails during item creation
   - Check image dimensions before finalizing thumbnail
   - If longest side > 200px, resize to 200px max (preserve aspect ratio)
   - If <= 200px, leave unchanged (already within spec)
   - Use existing image processing library (ImageMagick/MiniMagick)

3. **Implementation location:**
   - ACDA Portal's custom thumbnail processing job
   - Hook into existing job logic (don't create parallel logic)
   - Job fires on item creation, processes all thumbnails uniformly

### Option 2: CSS-Based Workaround (Quick Fix)
If job modification is complex, add CSS max-width constraint to thumbnail containers:
```scss
.thumbnail-preview {
  max-width: 200px;
  max-height: 200px;
  object-fit: contain;
}
```
**Note:** This masks the problem rather than fixing root cause; prefer Option 1.

## Acceptance Criteria
- [ ] Large thumbnails (>200px) automatically resize on import
- [ ] Small thumbnails (<200px) remain unchanged
- [ ] Aspect ratio preserved for all images
- [ ] Item browser page CSS formatting unbroken
- [ ] Import performance not noticeably degraded
- [ ] Works with existing bulk import workflow

## Testing Plan
1. Create test CSV with mix of thumbnail sizes (100px, 200px, 500px, 1000px)
2. Import via Bulkrax on dev environment
3. Verify visual layout on item browser page
4. Check actual file dimensions post-import (should be ~200px max)
5. Test with various image formats (JPG, PNG, GIF)

## Files to Research
- ACDA Portal's custom import code and background job classes
- Existing thumbnail processing job (likely Sidekiq, possibly GoodJob conversion branch)
- edm:preview field mapping
- Existing image processing in Hyrax/Hyku
- Item browser template/CSS

## Related Work
**⚠️ GoodJob Conversion**: Praneeth is working on converting ACDA Portal from Sidekiq to GoodJob (align with Hyku/other Samvera projects). Check if this branch exists and consider:
- Implementing thumbnail resize on the GoodJob branch (preferred) if it's in-progress
- Or implement on current main with Sidekiq, then re-base on GoodJob branch when ready
- Verify job logic is compatible with both systems during transition

## Implementation Steps
- [ ] Fork hydra_acda_portal_public
- [ ] Identify Bulkrax parser and field mapping
- [ ] Research Bulkrax image processing capabilities
- [ ] Implement auto-resize logic
- [ ] Add tests for image processing
- [ ] Test on dev environment
- [ ] Create PR with screenshots of before/after
- [ ] Address review feedback
- [ ] Merge to main

## Notes
- **Related Systems:** Bulkrax (importer), Hyrax (file handling), edm:preview field
- **Priority:** Medium (visual layout issue but doesn't prevent functionality)
- **Blocker:** None identified; can proceed immediately with research
