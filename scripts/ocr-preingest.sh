#!/bin/bash

# PDF Pre-Ingest OCR Processing Script
# Processes directories of PDF files to add OCR text layers where missing
# Separate from AI/Ollama remediation - focuses on PDF accessibility correction

set -euo pipefail

# Default values
WORKERS=1
DRY_RUN=false
OUTPUT_DIR=""
LOG_FILE=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS] <input_directory>

Batch process PDF files to add OCR text layers for accessibility.

OPTIONS:
    -w, --workers NUM       Number of parallel workers (default: 1)
    -o, --output DIR        Output directory for processed PDFs (default: in-place)
    -n, --dry-run           Show what would be processed without making changes
    -l, --log FILE          Log file for failures (default: ocr-preingest-<timestamp>.log)
    -h, --help              Show this help message

EXAMPLES:
    # Dry run to see what would be processed
    $0 --dry-run /data/pdfs

    # Process in-place with 4 parallel workers
    $0 --workers 4 /data/pdfs

    # Process to separate output directory
    $0 --output /data/pdfs-processed --workers 4 /data/pdfs

EOF
    exit 1
}

# Function to log messages
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

# Function to log errors
error_log() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}" >&2
    if [ -n "$LOG_FILE" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >> "$LOG_FILE"
    fi
}

# Function to check if PDF has text layer
has_text_layer() {
    local pdf_file="$1"
    # Use pdftotext to extract text, check if output is non-empty
    if pdftotext "$pdf_file" - 2>/dev/null | grep -q '[[:alnum:]]'; then
        return 0  # Has text
    else
        return 1  # No text
    fi
}

# Function to process a single PDF
process_pdf() {
    local input_pdf="$1"
    local output_pdf="$2"

    # Create output directory if needed
    local output_dir
    output_dir=$(dirname "$output_pdf")
    mkdir -p "$output_dir"

    if has_text_layer "$input_pdf"; then
        if [ "$DRY_RUN" = true ]; then
            echo "SKIP (has text): $input_pdf"
        else
            log "SKIP (has text): $input_pdf"
            # Copy file if output is different
            if [ "$input_pdf" != "$output_pdf" ]; then
                cp "$input_pdf" "$output_pdf"
            fi
        fi
        return 0
    fi

    if [ "$DRY_RUN" = true ]; then
        echo "OCR needed: $input_pdf -> $output_pdf"
        return 0
    fi

    log "Processing: $input_pdf -> $output_pdf"

    # Run OCR using ocrmypdf with --skip-text (safe for partially OCR'd documents)
    if ocrmypdf --skip-text "$input_pdf" "$output_pdf" 2>/dev/null; then
        log "SUCCESS: $output_pdf"
    else
        error_log "FAILED: $input_pdf"
        return 1
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -w|--workers)
            WORKERS="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -l|--log)
            LOG_FILE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        -*)
            error_log "Unknown option: $1"
            usage
            ;;
        *)
            INPUT_DIR="$1"
            shift
            ;;
    esac
done

# Validate input directory
if [ -z "${INPUT_DIR:-}" ]; then
    error_log "Input directory is required"
    usage
fi

if [ ! -d "$INPUT_DIR" ]; then
    error_log "Input directory does not exist: $INPUT_DIR"
    exit 1
fi

# Set default log file if not specified
if [ -z "$LOG_FILE" ]; then
    TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
    LOG_FILE="ocr-preingest-${TIMESTAMP}.log"
fi

# Set output directory to input if not specified
if [ -z "$OUTPUT_DIR" ]; then
    OUTPUT_DIR="$INPUT_DIR"
fi

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

log "Starting PDF pre-ingest OCR processing"
log "Input directory: $INPUT_DIR"
log "Output directory: $OUTPUT_DIR"
log "Workers: $WORKERS"
log "Dry run: $DRY_RUN"
log "Log file: $LOG_FILE"

# Find all PDF files
PDF_FILES=$(find "$INPUT_DIR" -type f -iname "*.pdf" | sort)

if [ -z "$PDF_FILES" ]; then
    log "No PDF files found in $INPUT_DIR"
    exit 0
fi

PDF_COUNT=$(echo "$PDF_FILES" | wc -l)
log "Found $PDF_COUNT PDF file(s) to process"

# Process PDFs
if [ "$DRY_RUN" = true ]; then
    echo "$PDF_FILES" | while read -r pdf_file; do
        # Calculate relative path for output
        relative_path="${pdf_file#$INPUT_DIR}"
        relative_path="${relative_path#/}"  # Remove leading slash
        output_pdf="$OUTPUT_DIR/$relative_path"
        process_pdf "$pdf_file" "$output_pdf"
    done
else
    # Use xargs for parallel processing
    echo "$PDF_FILES" | xargs -n 1 -P "$WORKERS" bash -c '
        input_pdf="$1"
        input_dir="$2"
        output_dir="$3"
        log_file="$4"

        # Calculate relative path for output
        relative_path="${input_pdf#$input_dir}"
        relative_path="${relative_path#/}"  # Remove leading slash
        output_pdf="$output_dir/$relative_path"

        # Source the script functions (this is a bit hacky but works)
        source '"$(dirname "$0")"'/'"$(basename "$0")"'

        process_pdf "$input_pdf" "$output_pdf"
    ' _ "$INPUT_DIR" "$OUTPUT_DIR" "$LOG_FILE"
fi

log "Processing complete. Check $LOG_FILE for any failures."
