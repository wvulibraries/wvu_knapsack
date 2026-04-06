#!/usr/bin/env bash
# ocr-preingest.sh — Batch OCR pre-ingest processor for PDF collections
#
# Run this BEFORE Bulkrax ingest on the directory of PDF files to be imported.
# PDFs that already carry an embedded text layer (e.g. Acrobat-processed staff
# files) are detected and skipped automatically, so it's safe to run against a
# mixed or already-partially-processed directory.
#
# After this script completes, import the processed directory via Bulkrax as
# usual.  OcrPdfJob (the in-app safety net) will detect the text layer and skip
# the heavy OCR step for any PDFs processed here.
#
# USAGE:
#   chmod +x scripts/ocr-preingest.sh
#   ./scripts/ocr-preingest.sh /path/to/pdfs
#
# OPTIONS:
#   --workers N   Number of parallel ocrmypdf processes (default: number of CPUs)
#   --dry-run     Report what would be processed without modifying any files
#   --output DIR  Write OCR'd PDFs into DIR instead of replacing files in place
#                 (preserves originals; DIR is created if it doesn't exist)
#   --log FILE    Path to write per-file failure log (default: ocr-preingest-<timestamp>.log)
#
# EXAMPLES:
#   # Dry-run: show which files would be OCR'd
#   ./scripts/ocr-preingest.sh --dry-run /data/pdfs
#
#   # In-place OCR, 4 workers
#   ./scripts/ocr-preingest.sh --workers 4 /data/pdfs
#
#   # Write OCR'd copies to /data/pdfs-ocr, keep originals untouched
#   ./scripts/ocr-preingest.sh --output /data/pdfs-ocr /data/pdfs
#
# REQUIREMENTS:
#   ocrmypdf  — install via: apt-get install ocrmypdf  (or: pip install ocrmypdf)
#   pdftotext — install via: apt-get install poppler-utils
#
# NOTES:
#   - Uses --skip-text so pages that already carry a text layer are untouched.
#     This is the same flag used by OcrPdfJob inside the Rails app.
#   - ocrmypdf modifies files in-place atomically (writes to a temp file first,
#     then renames), so a crash mid-run cannot corrupt the original file.
#   - Re-running after a partial failure is safe: already-processed PDFs will
#     be detected as "has text layer" and skipped instantly.

set -euo pipefail

# ─── defaults ────────────────────────────────────────────────────────────────
WORKERS=$(nproc 2>/dev/null || sysctl -n hw.logicalcpu 2>/dev/null || echo 2)
DRY_RUN=false
OUTPUT_DIR=""
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_FILE="ocr-preingest-${TIMESTAMP}.log"
INPUT_DIR=""

# ─── argument parsing ────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    --workers)
      WORKERS="${2:?--workers requires a value}"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --output)
      OUTPUT_DIR="${2:?--output requires a value}"
      shift 2
      ;;
    --log)
      LOG_FILE="${2:?--log requires a value}"
      shift 2
      ;;
    -*)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
    *)
      if [[ -n "$INPUT_DIR" ]]; then
        echo "Error: multiple input directories specified." >&2
        exit 1
      fi
      INPUT_DIR="$1"
      shift
      ;;
  esac
done

if [[ -z "$INPUT_DIR" ]]; then
  echo "Usage: $0 [--workers N] [--dry-run] [--output DIR] [--log FILE] <input-dir>" >&2
  exit 1
fi

if [[ ! -d "$INPUT_DIR" ]]; then
  echo "Error: input directory not found: $INPUT_DIR" >&2
  exit 1
fi

# ─── dependency checks ───────────────────────────────────────────────────────
if ! command -v ocrmypdf &>/dev/null; then
  echo "Error: ocrmypdf not found in PATH." >&2
  echo "  Install: apt-get install ocrmypdf  OR  pip install ocrmypdf" >&2
  exit 1
fi

if ! command -v pdftotext &>/dev/null; then
  echo "Error: pdftotext not found in PATH." >&2
  echo "  Install: apt-get install poppler-utils" >&2
  exit 1
fi

# ─── output directory setup ──────────────────────────────────────────────────
if [[ -n "$OUTPUT_DIR" ]]; then
  if [[ "$DRY_RUN" == "false" ]]; then
    mkdir -p "$OUTPUT_DIR"
  fi
fi

# ─── helpers ─────────────────────────────────────────────────────────────────

# Returns 0 (true) if the PDF already has an embedded text layer.
has_text_layer() {
  local pdf="$1"
  local text
  text=$(pdftotext "$pdf" - 2>/dev/null | tr -d '[:space:]')
  [[ -n "$text" ]]
}

# Processes a single PDF file.  Called via xargs for parallel execution.
process_pdf() {
  local pdf="$1"
  local output_dir="$2"
  local dry_run="$3"
  local log_file="$4"

  if has_text_layer "$pdf"; then
    echo "SKIPPED: $pdf" | tee -a "$log_file"
    return 0
  fi

  if [[ "$dry_run" == "true" ]]; then
    echo "WOULD_OCR: $pdf" | tee -a "$log_file"
    return 0
  fi

  # Determine output path
  local dest
  if [[ -n "$output_dir" ]]; then
    # Preserve relative path structure inside output directory
    local rel="${pdf#"$5/"}"   # $5 = INPUT_DIR passed as 5th arg
    dest="${output_dir}/${rel}"
    mkdir -p "$(dirname "$dest")"
  else
    dest="$pdf"   # in-place (ocrmypdf renames atomically)
  fi

  if ocrmypdf \
       --skip-text \
       --output-type pdf \
       --quiet \
       "$pdf" \
       "$dest" 2>>"$log_file"; then
    echo "OCRD: $pdf" | tee -a "$log_file"
  else
    echo "FAILED: $pdf" | tee -a "$log_file"
    return 1
  fi
}

export -f process_pdf has_text_layer

# ─── collect files ───────────────────────────────────────────────────────────
echo ""
echo "=== PDF Pre-ingest OCR Processor ==="
echo "  Input:    $INPUT_DIR"
echo "  Output:   ${OUTPUT_DIR:-in-place}"
echo "  Workers:  $WORKERS"
echo "  Dry-run:  $DRY_RUN"
echo "  Log:      $LOG_FILE"
echo ""

# Count PDFs first so we can show progress
PDF_COUNT=$(find "$INPUT_DIR" -type f -iname "*.pdf" | wc -l | tr -d ' ')
echo "Found $PDF_COUNT PDF file(s) to evaluate."
echo ""

if [[ "$PDF_COUNT" -eq 0 ]]; then
  echo "Nothing to do."
  exit 0
fi

# ─── parallel processing ─────────────────────────────────────────────────────
# xargs -P launches up to WORKERS processes in parallel.
# All per-file status lines (SKIPPED/OCRD/WOULD_OCR/FAILED) are written to
# LOG_FILE via tee inside process_pdf so the summary can count them accurately.
find "$INPUT_DIR" -type f -iname "*.pdf" -print0 |
  xargs -0 -P "$WORKERS" -I{} bash -c \
    'process_pdf "$@"' _ {} \
    "$OUTPUT_DIR" "$DRY_RUN" "$LOG_FILE" "$INPUT_DIR"

# ─── summary ─────────────────────────────────────────────────────────────────
echo ""
echo "=== Summary ==="

SKIPPED=$(grep -c '^SKIPPED:' "$LOG_FILE" 2>/dev/null || echo 0)
OCRD=$(grep    -c '^OCRD:'    "$LOG_FILE" 2>/dev/null || echo 0)
WOULD=$(grep   -c '^WOULD_OCR:' "$LOG_FILE" 2>/dev/null || echo 0)
FAILED=$(grep  -c '^FAILED:'  "$LOG_FILE" 2>/dev/null || echo 0)

if [[ "$DRY_RUN" == "true" ]]; then
  echo "  Would skip (already has text layer): $SKIPPED"
  echo "  Would OCR: $WOULD"
  echo "  Dry-run complete. No files were modified."
else
  echo "  Skipped (already has text layer): $SKIPPED"
  echo "  OCR'd: $OCRD"
  echo "  Failed: $FAILED"
  echo "  Log: $LOG_FILE"
  if [[ "$FAILED" -gt 0 ]]; then
    echo ""
    echo "  *** $FAILED file(s) failed — see $LOG_FILE ***"
    echo "  Re-run this script after fixing any errors. Already-processed files"
    echo "  will be skipped automatically on subsequent runs."
    exit 1
  fi
fi
echo ""
echo "Done. Import the processed directory via Bulkrax when ready."
echo ""
