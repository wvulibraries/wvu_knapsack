# typed: strict

require 'tempfile'
require 'fileutils'

# Generates ADA-compliant alt_text for PDF FileSets.
#
# Strategy (in order):
#   1. Extract embedded text with pdftotext (fast, works for text-layer PDFs).
#      Feed that text to AltTextGeneratorService for a 125-char summary.
#   2. If no embedded text (scanned/image-only PDF), rasterize the first page
#      to PNG via pdftoppm and pass the image bytes to VisionService (Moondream).
#
# Both pdftotext and pdftoppm are already present in the Hyku Docker image
# (they are installed for the existing PDF text indexing feature).
#
# @see AltTextGeneratorService  — 125-char text summarisation via Ollama
# @see VisionService            — Ollama multimodal image description
class PdfAccessibilityService
  # Cap how many characters of extracted PDF text we send to Ollama.
  # Enough for a meaningful summary; prevents token overflow.
  MAX_TEXT_CHARS = 2_000

  # @param file_set [FileSet] must have mime_type 'application/pdf'
  # @return [String, nil] sanitized alt_text, or nil if neither path yields a result
  def self.call(file_set)
    content = file_set.original_file&.content
    unless content.present?
      Rails.logger.warn("[PdfAccessibilityService] No file content for FileSet #{file_set.id} — not yet attached")
      return nil
    end

    # Path 1: embedded text layer
    text = extract_text(content)
    if text.present?
      Rails.logger.info("[PdfAccessibilityService] Text path for FileSet #{file_set.id} (#{text.length} chars extracted)")
      return AltTextGeneratorService.call(text)
    end

    # Path 2: image-only / scanned PDF — rasterize first page and vision it
    Rails.logger.info("[PdfAccessibilityService] No embedded text for FileSet #{file_set.id} — attempting rasterization")
    image_bytes = rasterize_first_page(content)
    unless image_bytes.present?
      Rails.logger.warn("[PdfAccessibilityService] Rasterization failed for FileSet #{file_set.id} — skipping")
      return nil
    end

    VisionService.call_with_bytes(image_bytes, file_set.id)
  rescue StandardError => e
    Rails.logger.error("[PdfAccessibilityService] Error for FileSet #{file_set.id}: #{e.message}")
    nil
  end

  # Extracts the embedded text layer from PDF bytes using pdftotext.
  # Returns nil if pdftotext is unavailable or the PDF has no text layer.
  #
  # @param pdf_bytes [String] raw PDF binary content
  # @return [String, nil]
  def self.extract_text(pdf_bytes)
    text = IO.popen(['pdftotext', '-', '-'], 'r+b') do |io|
      io.write(pdf_bytes)
      io.close_write
      io.read
    end
    cleaned = text.to_s.tr("\n", ' ').squeeze(' ').strip
    cleaned.empty? ? nil : cleaned[0, MAX_TEXT_CHARS]
  rescue Errno::ENOENT
    Rails.logger.warn('[PdfAccessibilityService] pdftotext not found — skipping text extraction path')
    nil
  rescue StandardError => e
    Rails.logger.warn("[PdfAccessibilityService] pdftotext error: #{e.message}")
    nil
  end

  # Rasterizes the first page of a PDF to PNG bytes using pdftoppm.
  # Uses temp files (pdftoppm does not support stdin/stdout piping for PNG output).
  # All temp files are cleaned up in an ensure block.
  #
  # @param pdf_bytes [String] raw PDF binary content
  # @return [String, nil] raw PNG bytes, or nil on failure
  def self.rasterize_first_page(pdf_bytes)
    pdf_tmp   = Tempfile.new(['ai_pdf_input', '.pdf'])
    pages_dir = Dir.mktmpdir('ai_pdf_pages')

    begin
      pdf_tmp.binmode
      pdf_tmp.write(pdf_bytes)
      pdf_tmp.flush

      output_prefix = File.join(pages_dir, 'page')

      # Array form of system() — no shell involved, no injection risk.
      # -r 150  = 150 dpi (sufficient for Moondream; higher DPI = larger base64 payload)
      # -f 1 -l 1 = first page only
      # -png    = PNG output
      success = system('pdftoppm', '-r', '150', '-f', '1', '-l', '1', '-png',
                       pdf_tmp.path, output_prefix)

      unless success
        Rails.logger.warn('[PdfAccessibilityService] pdftoppm exited non-zero')
        return nil
      end

      # pdftoppm names output files <prefix>-1.png or <prefix>-01.png depending on version
      output_file = Dir["#{output_prefix}*.png"].first
      unless output_file && File.exist?(output_file)
        Rails.logger.warn('[PdfAccessibilityService] pdftoppm produced no PNG output')
        return nil
      end

      File.binread(output_file)
    ensure
      pdf_tmp.close!
      FileUtils.rm_rf(pages_dir)
    end
  rescue Errno::ENOENT
    Rails.logger.warn('[PdfAccessibilityService] pdftoppm not found — cannot rasterize PDF')
    nil
  rescue StandardError => e
    Rails.logger.warn("[PdfAccessibilityService] rasterization error: #{e.message}")
    nil
  end
end
