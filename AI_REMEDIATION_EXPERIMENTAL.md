# AI Remediation (Ollama Testing Branch)

**Status:**

> ⚠️ EXPERIMENTAL — NOT FOR PRODUCTION USE

---

## Current Features

- **AltTextGeneratorService** with Ollama integration (Moondream/Llama3 models supported)
  - `stream: false` enforced — prevents NDJSON parse errors from Ollama's default streaming mode
  - Faraday timeouts configurable via `OLLAMA_OPEN_TIMEOUT` (default: 10s) and `OLLAMA_READ_TIMEOUT` (default: 45s)
  - Only invoked when `description` is present; clean `nil` return otherwise
- **VisionService** — Ollama multimodal API path for image FileSets with no description text
  - Base64-encodes `file_set.original_file.content` and sends it in Ollama's `images` field
  - Guards against unsupported MIME types and unattached files (logs warning, returns nil)
  - Exposes `call_with_bytes(image_bytes, context_id)` used by `PdfAccessibilityService` for rasterized PDF pages
  - Reuses `AltTextGeneratorService::SanitizeAltText` for 125-char compliance
- **PdfAccessibilityService** — ADA-compliant alt_text generation for PDF FileSets
  - **Path 1 (text-layer PDF):** extracts embedded text with `pdftotext` (already in the Docker image), feeds up to 2,000 chars to `AltTextGeneratorService` for a 125-char summary
  - **Path 2 (scanned/image-only PDF):** rasterizes the first page to PNG at 150dpi via `pdftoppm`, passes raw PNG bytes to `VisionService.call_with_bytes` (Moondream multimodal)
  - Temp files created with `Tempfile` + `Dir.mktmpdir`; always cleaned up in `ensure` blocks
  - All system calls use array form — no shell interpolation, no injection risk
- **RemediateAltTextJob** — text-description path; runs on `ai_remediation` queue, priority `-30`
- **AiDescriptionJob** — visual-only path for images with no description; same queue/priority
- **OcrPdfJob** — PDF stage 1; checks for an embedded text layer via `pdftotext`; runs `ocrmypdf --skip-text` on scanned/image-only PDFs; replaces the stored file in Fedora with the OCR'd version; always cascades to `RemediatePdfJob` (stage 2); priority `-28`
  - `--skip-text` leaves pages that already carry text untouched (safe for partial scans)
  - Falls back gracefully if `ocrmypdf` binary is absent — logs warning and cascades to `RemediatePdfJob` which uses the vision fallback
  - Uses a separate `pdf_ocr_processing` GoodJob concurrency key (CPU-bound OCR, not Ollama)
- **RemediatePdfJob** — PDF stage 2; delegates to `PdfAccessibilityService`; priority `-30`
- `RemediateAltTextJob`, `AiDescriptionJob`, and `RemediatePdfJob` share the `ollama_remediation` GoodJob concurrency key so the combined in-flight Ollama request count never exceeds `OLLAMA_NUM_PARALLEL`
- `OcrPdfJob` uses a separate `pdf_ocr_processing` concurrency key capped at `PDF_OCR_CONCURRENCY` (default: 2) — this is CPU-bound, not Ollama-bound
- **AiMetadataBehavior concern** routes `after_create_commit` to the correct job:
  - `pdf?` → `OcrPdfJob` first (always — ensures the stored file has a text layer regardless of whether a description exists)
  - `description.present? && image?` → `RemediateAltTextJob`
  - `description.blank? && image?` → `AiDescriptionJob`
- **`config/initializers/ai_metadata_behavior.rb`** (knapsack-owned) — wires `AiMetadataBehavior` into `FileSet` via `config.to_prepare`, which survives Zeitwerk hot-reload in development
- **`config/initializers/good_job_ai_remediation.rb`** (knapsack-owned) — GoodJob queue cap and shutdown timeout override; does not touch the submodule's `good_job.rb`
- **125-character Documentation Mandate** enforced in `AltTextGeneratorService::SanitizeAltText` — strips markdown, normalises smart quotes, collapses whitespace, hard-truncates at 125 chars
- `rake hyku:ai:test_record[identifier]` — canary test using Bulkrax `source_identifier_tesim` (falls back to `identifier_tesim`); prints current alt text, detected path (TEXT vs VISION vs NONE), and the AI result without saving
- `rake hyku:ai:audit` — grep the Rails log for `AI_REMEDIATION_FAILURE` tags and report failed FileSet IDs
- `rake hyku:ai:reenqueue_failures` — parse failure IDs from the log and re-enqueue each to the correct job

## Scope

**Primary target (this branch):** ~54,000 image records (JPEG, TIFF, PNG, etc.) with incomplete or missing `alt_text` metadata.

**PDF collections** are a separate initiative that runs in parallel with the image remediation. Because PDF collections can run into the thousands of files, **pre-ingest batch OCR is the recommended approach** — it is faster, simpler, and avoids Fedora file replacement entirely.

### PDF processing strategy

| Scenario | Recommended tool | When to use |
|---|---|---|
| Large PDF batch (hundreds–thousands of files) | `scripts/ocr-preingest.sh` | **Before** Bulkrax import, directly on disk |
| Mixed-format import / stray PDFs | `OcrPdfJob` (automatic, post-ingest) | After import — fires automatically on `after_create_commit` |
| PDF already staff-processed via Acrobat | Both paths detect-and-skip automatically | Either workflow |

### `scripts/ocr-preingest.sh` (pre-ingest)

Run directly against the PDF directory on the server before import. Does not require Rails to be running.

```sh
# Dry-run: see which files would be OCR'd (no files modified)
./scripts/ocr-preingest.sh --dry-run /data/pdfs

# In-place OCR — 4 parallel workers (safe on multi-core VMs)
./scripts/ocr-preingest.sh --workers 4 /data/pdfs

# Write OCR'd copies to a separate directory (preserves originals)
./scripts/ocr-preingest.sh --output /data/pdfs-ocr --workers 4 /data/pdfs
```

- Uses `pdftotext` to detect PDFs that already have a text layer and **skips them instantly**
- Uses `ocrmypdf --skip-text` on all others (safe for partially-OCR'd documents)
- Parallel execution via `xargs -P N` — set `--workers` to the server's CPU count for throughput
- Idempotent: re-running after a partial failure is safe — already-processed files are skipped
- Failures are written to `ocr-preingest-<timestamp>.log` for triage

After the script completes, import the processed directory via Bulkrax. `OcrPdfJob` will detect the existing text layer on each FileSet and skip the OCR step, going straight to `RemediatePdfJob` for `alt_text` generation.

### `OcrPdfJob` (post-ingest safety net)

Fires automatically via `after_create_commit` for any PDF FileSet created by Bulkrax (or any other import path). Handles:
- PDFs that were imported without going through `ocr-preingest.sh`
- Edge cases where `ocr-preingest.sh` failed on specific files
- Future ingest runs where pre-ingest OCR was not performed

Two things happen to each PDF FileSet during or after import:

1. **File-level:** `OcrPdfJob` checks for an embedded text layer; if absent it runs `ocrmypdf`, replaces the Fedora-stored file with the OCR'd version, and cascades to stage 2. If `ocr-preingest.sh` was run first, this step is a near-instant skip.
2. **Metadata-level:** `RemediatePdfJob` generates a 125-char `alt_text` value for the Hyku record using the embedded text (fast path) or Moondream vision (fallback).

This covers both the repository metadata required for the web UI (WCAG 2.1 SC 1.1.1) and screen reader accessibility of the PDF file itself (Section 508 / PDF/UA).

---

## Workflow

1. **Import a subset** of records to a Dev VM using Bulkrax (CSV or OAI).
2. **AI Remediation:**
   - Set `AI_ENABLED=true`, `OLLAMA_NUM_PARALLEL`, and `OLLAMA_READ_TIMEOUT` on the Dev VM before starting the GoodJob worker.
   - Start a dedicated GoodJob worker targeting the `ai_remediation` queue: `bundle exec good_job start --queues=ai_remediation`.
   - `RemediateAltTextJob` runs in the background, generating `alt_text` for eligible FileSets using Ollama. Jobs run after all ingest/derivative work completes (priority `-30`).
   - Connection/timeout failures are logged via `Rails.logger` tagged with `AI_REMEDIATION_FAILURE`. Use `grep AI_REMEDIATION_FAILURE log/development.log` to triage.
3. **Export:**
   - Use Bulkrax export to generate a refined CSV. Because `file_set.update_index` is called after each save, `alt_text_tesim` is available in Solr immediately.
4. **Production Prep:**
   - Review and clean the exported CSV as needed before ingesting to Production.

---

## Local Test Run Procedure (50-record mixed-metadata validation)

Use this procedure before scaling to an 18k or 54k chunk.

### What each record type will do

| Record condition | Stage 1 job | Stage 2 job | Service called |
|---|---|---|---|
| `description` present, is an image, `alt_text` blank | `RemediateAltTextJob` | — | `AltTextGeneratorService` (text summarisation) |
| No description, is an image, `alt_text` blank | `AiDescriptionJob` | — | `VisionService` (Moondream multimodal) |
| PDF with `description` (any OCR state) | `OcrPdfJob` (ensures text layer) | `RemediatePdfJob` | `AltTextGeneratorService` from description (fastest) |
| PDF — pre-processed by `ocr-preingest.sh` or Acrobat | `OcrPdfJob` (text detected, instant skip) | `RemediatePdfJob` | `PdfAccessibilityService` → `AltTextGeneratorService` |
| PDF — scanned/image-only, no prior OCR | `OcrPdfJob` (runs `ocrmypdf`) | `RemediatePdfJob` | `PdfAccessibilityService` → `AltTextGeneratorService` |
| PDF — OCR failed (`ocrmypdf` unavailable) | `OcrPdfJob` (logs warning) | `RemediatePdfJob` | `PdfAccessibilityService` → `pdftoppm` → `VisionService` |
| `alt_text` already present | No job — guard returns early | — | — |

### Step-by-step

```sh
# 1. Bring up the full stack.
#    On first run this downloads the moondream weights into the 'ollama' Docker volume (~1.7 GB).
#    Subsequent starts skip straight to the health check.
sh up.sc.local.sh

# 2. Import your 50-record CSV via the Bulkrax admin UI.
#    Use a deliberately mixed set:
#      - some rows with description filled in
#      - some rows with description blank (image files)
#      - some rows with description blank (PDF files)
#      - some rows with alt_text already present (should be skipped)

# 3. Canary-test a single known identifier BEFORE watching the full queue.
#    This calls the service live without saving anything to the database.
rake hyku:ai:test_record[your_source_identifier]
#    Output shows:
#      Work/FileSet IDs, MIME type, current alt_text value,
#      detected PATH (TEXT / VISION / NONE), and the raw AI result.

# 4. Watch the worker process the ai_remediation queue.
sc logs worker -f | grep -E 'AI_REMEDIATION|RemediateAlt|AiDescription'

# 5. After the queue drains, audit for failures.
rake hyku:ai:audit
#    Greps log/development.log for AI_REMEDIATION_FAILURE tags and lists failed FileSet IDs.

# 6. Re-enqueue anything that failed (idempotent — skips FileSets that now have alt_text).
rake hyku:ai:reenqueue_failures

# 7. Verify Solr picked up the new values (required for Bulkrax export to include alt_text).
#    In the Hyku admin UI: search for one of the remediated works and confirm alt_text appears.
#    Or via Solr directly:
#      curl 'http://localhost:8983/solr/hydra-development/select?q=alt_text_tesim:*&rows=5&fl=id,alt_text_tesim'

# 8. Run a Bulkrax export and open the CSV to confirm the alt_text column is populated.
```

### Triage quick-reference

```sh
# All AI log activity (both successes and failures)
sc logs worker -f | grep -iE 'RemediateAlt|AiDescription|OcrPdf|VisionService|AI_REMEDIATION'

# Only failures
grep 'AI_REMEDIATION_FAILURE' log/development.log

# Check whether a PDF already has a text layer (run on the server before import)
pdftotext /path/to/file.pdf - | head -5

# Batch pre-ingest OCR — dry-run first, then process (see scripts/ocr-preingest.sh)
./scripts/ocr-preingest.sh --dry-run /path/to/pdfs
./scripts/ocr-preingest.sh --workers 4 /path/to/pdfs

# Check Ollama is alive and which model is loaded
docker compose exec ollama ollama ps

# Pull a different model for testing (e.g. llama3 for the text path)
docker compose exec ollama ollama pull llama3
# Then set OLLAMA_MODEL=llama3 in .env.development and restart the worker.
```

---

## Environment Variables

| Variable | Default | Purpose |
|---|---|---|
| `AI_ENABLED` | _(unset)_ | Must be `true` to enable job processing |
| `OLLAMA_URL` | `http://ollama:11434/api/generate` | Ollama endpoint |
| `OLLAMA_MODEL` | `moondream` | Model name (`moondream` or `llama3`) |
| `OLLAMA_NUM_PARALLEL` | `3` | Ollama parallel slots; also caps GoodJob thread count for `ai_remediation` queue |
| `OLLAMA_OPEN_TIMEOUT` | `10` | Faraday TCP connect timeout (seconds) |
| `OLLAMA_READ_TIMEOUT` | `45` | Faraday inference read timeout (seconds); GoodJob `shutdown_timeout` is set to this + 30s |
| `PDF_OCR_CONCURRENCY` | `2` | Max concurrent `ocrmypdf` processes (CPU-bound; independent of Ollama concurrency) |

---

## Known Gaps / Future Work

- **Archivist Review Loop:** No UI flag or `status` field yet to distinguish AI-generated vs. human-verified `alt_text` for archivist QA.
- **SMART_QUOTES Map:** The `SanitizeAltText::SMART_QUOTES` hash keys are raw Unicode bytes; verify encoding is preserved correctly on the Dev VM's locale before a full 54k run.
- **File Not Yet Attached:** `VisionService` and `PdfAccessibilityService` return nil and log a warning if called before `AttachFilesToWorkJob` has completed. Unlikely given priority ordering (`-30` vs `-1`) but worth monitoring on the first 18k chunk.
- **pdftoppm DPI Tuning:** 150dpi is the default rasterization resolution. Very dense scanned pages may need 200–300dpi for Moondream to resolve text; increase `PDFTOPPM_DPI` if vision results are poor on scanned PDFs (to be wired up).

### PDF OCR Pipeline — Implementation Notes

The `OcrPdfJob` → `RemediatePdfJob` cascade is intended for PDFs imported without a prior Acrobat workflow. The job is safe to run on all PDFs:

- PDFs that already carry a text layer (staff-processed via Acrobat) are detected by `pdftotext` → `OcrPdfJob` skips `ocrmypdf` and goes straight to `RemediatePdfJob`.
- `--skip-text` in `ocrmypdf` also provides a second layer of protection on partially-OCR'd documents.
- Fedora retains full version history for all file objects; replacing content with an OCR'd version is reversible.
- `CharacterizeJob` is **not** re-triggered after OCR (FITS characterization values are unchanged for OCR'd PDFs) — this avoids a second derivative-generation wave that could interfere with the 54k image run.
