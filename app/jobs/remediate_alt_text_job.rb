# typed: strict

class RemediateAltTextJob < ApplicationJob
  queue_as :ai_remediation

  # GoodJob concurrency guard: hard cap matches OLLAMA_NUM_PARALLEL so we never
  # have more in-flight Ollama requests than it can serve in parallel.
  # Jobs beyond the limit are re-enqueued rather than blocked in a thread.
  include GoodJob::ActiveJobExtensions::Concurrency
  good_job_control_concurrency_with(
    total_limit: -> { ENV.fetch('OLLAMA_NUM_PARALLEL', 3).to_i },
    key: 'ollama_remediation'
  )

  # GoodJob-compatible worker for alt_text remediation
  # @param file_set_id [String, Integer]
  def perform(file_set_id)
    return unless ENV['AI_ENABLED'] == 'true'
    begin
      file_set = Hyrax.query_service.find_by(id: Valkyrie::ID.new(file_set_id))
    rescue Valkyrie::Persistence::ObjectNotFoundError
      return
    end
    return unless file_set.alt_text.blank? && file_set.description.present?
    begin
      summary = AltTextGeneratorService.call(file_set.description.first)
      if summary.present?
        file_set.alt_text = [summary]
        Hyrax.persister.save(resource: file_set)
        Hyrax.index_adapter.save(resource: file_set)
        Rails.logger.info("[RemediateAltTextJob] Alt text updated for FileSet #{file_set_id}")
      end
    rescue Faraday::ConnectionFailed, Faraday::TimeoutError => e
      log_failure(file_set_id, 'unknown', e)
    rescue StandardError => e
      Rails.logger.error("[RemediateAltTextJob] Error for FileSet #{file_set_id}: #{e.message}")
    end
  end

  private

  # Thread-safe failure log: Rails.logger is already mutex-protected.
  def log_failure(file_set_id, work_id, error)
    msg = "file_set_id=#{file_set_id}, work_id=#{work_id}, error=#{error.class}: #{error.message}"
    Rails.logger.tagged('AI_REMEDIATION_FAILURE') { Rails.logger.error(msg) }
  end
end
