# frozen_string_literal: true

# OcrPdfJob — Stage 1 of the PDF accessibility pipeline.
#
# Reads the PDF from Fedora, checks whether it already contains an embedded text
# layer, and runs `ocrmypdf` when needed.  After ensuring the stored file has a
# text layer the job cascades to RemediatePdfJob (stage 2) which generates the
# Hyku `alt_text` metadata field.
#
# Cascade:
#   after_create_commit → OcrPdfJob (priority -28)
#     → [if text layer absent] ocrmypdf → replace file in Fedora
#     → RemediatePdfJob (priority -30) → PdfAccessibilityService → alt_text saved
#
# This job does NOT call Ollama, so it does not use the ollama_remediation
# concurrency key.  A separate PDF_OCR_CONCURRENCY key prevents runaway CPU
# saturation from concurrent OCR processes.
class OcrPdfJob < ApplicationJob
  queue_as :ai_remediation

  include GoodJob::ActiveJobExtensions::Concurrency
  good_job_control_concurrency_with(
    total_limit: -> { ENV.fetch('PDF_OCR_CONCURRENCY', 2).to_i },
    key: 'pdf_ocr_processing'
  )

  def perform(file_set_id)
    return unless ENV['AI_ENABLED'] == 'true'

    file_set = FileSet.find_by(id: file_set_id)
    return unless file_set
    return unless file_set.mime_type == 'application/pdf'

    content = file_set.original_file&.content
    unless content.present?
      Rails.logger.warn("[OcrPdfJob] FileSet #{file_set_id} has no attached file — skipping.")
      return
    end

    existing_text = extract_text(content)
    if existing_text.present?
      # Already has an embedded text layer — Acrobat-processed or previously OCR'd.
      # Skip the expensive ocrmypdf step and go straight to alt_text generation.
      Rails.logger.info("[OcrPdfJob] FileSet #{file_set_id} already has a text layer — cascading to RemediatePdfJob.")
      RemediatePdfJob.perform_later(file_set_id)
      return
    end

    # Scanned / image-only PDF — needs OCR.
    ocr_bytes = run_ocrmypdf(content, file_set_id)
    if ocr_bytes.present?
      replace_fedora_content(file_set, ocr_bytes)
      Rails.logger.info("[OcrPdfJob] FileSet #{file_set_id} OCR'd and saved to Fedora (#{ocr_bytes.bytesize} bytes).")
    else
      # ocrmypdf failed (missing binary, corrupt PDF, etc.) — log and continue.
      # RemediatePdfJob will fall back to the pdftoppm→VisionService path.
      Rails.logger.warn("[OcrPdfJob] ocrmypdf failed for FileSet #{file_set_id} — cascading to RemediatePdfJob with vision fallback.")
    end

    # Always cascade regardless of OCR outcome so alt_text is attempted via
    # PdfAccessibilityService (which has its own text/vision fallback logic).
    RemediatePdfJob.perform_later(file_set_id)
  rescue StandardError => e
    Rails.logger.tagged('AI_REMEDIATION_FAILURE') do
      Rails.logger.error("[OcrPdfJob] file_set_id=#{file_set_id}, error=#{e.class}: #{e.message}")
    end
  end

  private

  # Quick text extraction using pdftotext.  Returns blank string if binary not
  # available or if the PDF has no text layer.
  def extract_text(pdf_bytes)
    pdf_tmp = Tempfile.new(['ocr_check', '.pdf'])
    pdf_tmp.binmode
    pdf_tmp.write(pdf_bytes)
    pdf_tmp.flush

    text_tmp = Tempfile.new(['ocr_check_text', '.txt'])

    success = system('pdftotext', pdf_tmp.path, text_tmp.path)
    return '' unless success

    text_tmp.read.strip
  rescue Errno::ENOENT
    Rails.logger.warn('[OcrPdfJob] pdftotext not found in PATH — cannot check for existing text layer.')
    ''
  ensure
    pdf_tmp&.close!
    text_tmp&.close!
  end

  # Run ocrmypdf on raw PDF bytes and return the OCR'd PDF bytes, or nil on failure.
  # --skip-text leaves pages that already have text untouched (safe for partial scans).
  # --output-type pdf  produces standard PDF output (not PDF/A) for broadest compatibility.
  # --quiet            suppresses informational output; errors still go to stderr.
  def run_ocrmypdf(pdf_bytes, file_set_id)
    pdf_in  = Tempfile.new(['ocr_input', '.pdf'])
    pdf_out = Tempfile.new(['ocr_output', '.pdf'])

    pdf_in.binmode
    pdf_in.write(pdf_bytes)
    pdf_in.flush

    success = system(
      'ocrmypdf',
      '--skip-text',
      '--output-type', 'pdf',
      '--quiet',
      pdf_in.path,
      pdf_out.path
    )

    unless success
      Rails.logger.warn("[OcrPdfJob] ocrmypdf exited non-zero for FileSet #{file_set_id}.")
      return nil
    end

    File.binread(pdf_out.path)
  rescue Errno::ENOENT
    Rails.logger.warn('[OcrPdfJob] ocrmypdf binary not found in PATH.')
    nil
  ensure
    pdf_in&.close!
    pdf_out&.close!
  end

  # Replaces the PDF file content stored in Fedora with the OCR'd version.
  # ActiveFedora persists the new content on #save; Fedora retains version history.
  def replace_fedora_content(file_set, new_bytes)
    original = file_set.original_file
    original.content   = new_bytes
    original.mime_type = 'application/pdf'
    original.save
  end
end
