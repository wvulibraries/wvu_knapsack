# typed: strict

class RemediatePdfJob < ApplicationJob
  queue_as :ai_remediation

  # Shares the ollama_remediation concurrency key with RemediateAltTextJob and
  # AiDescriptionJob so all three job types together never exceed OLLAMA_NUM_PARALLEL
  # concurrent Ollama requests.
  include GoodJob::ActiveJobExtensions::Concurrency
  good_job_control_concurrency_with(
    total_limit: -> { ENV.fetch('OLLAMA_NUM_PARALLEL', 3).to_i },
    key: 'ollama_remediation'
  )

  # Generates ADA-compliant alt_text for a PDF FileSet.
  #
  # Source priority for the 125-char alt_text:
  #   1. description field — if present, summarise it directly (fastest, no disk I/O)
  #   2. PdfAccessibilityService — pdftotext from text-layer PDF → AltTextGeneratorService
  #   3. PdfAccessibilityService — pdftoppm rasterization → VisionService (last resort)
  #
  # Note: OcrPdfJob (stage 1) always runs before this job and ensures the stored
  # PDF file has an embedded text layer, so path 2 succeeds for most PDFs.
  #
  # @param file_set_id [String, Integer]
  def perform(file_set_id)
    return unless ENV['AI_ENABLED'] == 'true'

    begin
      file_set = Hyrax.query_service.find_by(id: Valkyrie::ID.new(file_set_id))
    rescue Valkyrie::Persistence::ObjectNotFoundError
      return
    end
    return unless file_set.alt_text.blank?
    begin
      mime_type = Hyrax.custom_queries.find_original_file(file_set: file_set).mime_type.to_s rescue ''
    rescue StandardError
      mime_type = ''
    end
    return unless mime_type == 'application/pdf'

    summary = if file_set.description.present?
                AltTextGeneratorService.call(file_set.description.first)
              else
                PdfAccessibilityService.call(file_set)
              end

    if summary.present?
      file_set.alt_text = [summary]
      Hyrax.persister.save(resource: file_set)
      Hyrax.index_adapter.save(resource: file_set)
      Rails.logger.info("[RemediatePdfJob] Alt text set for PDF FileSet #{file_set_id}")
    else
      Rails.logger.warn("[RemediatePdfJob] No alt text generated for PDF FileSet #{file_set_id} 4 all paths returned nil")
    end
  rescue StandardError => e
    Rails.logger.tagged('AI_REMEDIATION_FAILURE') do
      Rails.logger.error("[RemediatePdfJob] file_set_id=#{file_set_id}, error=#{e.class}: #{e.message}")
    end
  end
end
