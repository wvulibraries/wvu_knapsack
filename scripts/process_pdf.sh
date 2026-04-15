#!/bin/bash

# PDF OCR Processing Script
# This script processes PDF files using OCR tools for text extraction and accessibility

set -e

# Function to display usage
usage() {
    echo "Usage: $0 <input_pdf> [output_pdf]"
    echo "  input_pdf: Path to the PDF file to process"
    echo "  output_pdf: Optional output path for OCR'd PDF (defaults to input_ocr.pdf)"
    exit 1
}

# Check if input file is provided
if [ $# -lt 1 ]; then
    usage
fi

INPUT_PDF="$1"
OUTPUT_PDF="${2:-${INPUT_PDF%.*}_ocr.pdf}"

# Check if input file exists
if [ ! -f "$INPUT_PDF" ]; then
    echo "Error: Input file '$INPUT_PDF' not found"
    exit 1
fi

echo "Processing PDF: $INPUT_PDF"
echo "Output will be: $OUTPUT_PDF"

# Extract text first to check if OCR is needed
echo "Extracting existing text..."
pdftotext "$INPUT_PDF" /tmp/temp_text.txt 2>/dev/null

# Check if the PDF already has text
if [ -s /tmp/temp_text.txt ]; then
    echo "PDF already contains text. Running OCR to improve accessibility..."
    ocrmypdf --force-ocr "$INPUT_PDF" "$OUTPUT_PDF"
else
    echo "PDF appears to be image-only. Running OCR..."
    ocrmypdf "$INPUT_PDF" "$OUTPUT_PDF"
fi

# Clean up
rm -f /tmp/temp_text.txt

echo "OCR processing complete. Output saved to: $OUTPUT_PDF"

# Optional: Extract text from the processed PDF for verification
echo "Extracting text from processed PDF for verification..."
pdftotext "$OUTPUT_PDF" "${OUTPUT_PDF%.*}.txt"
echo "Text extracted to: ${OUTPUT_PDF%.*}.txt"