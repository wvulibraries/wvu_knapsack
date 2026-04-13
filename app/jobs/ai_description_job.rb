# typed: strict

class AiDescriptionJob < ApplicationJob
  queue_as :ai_remediation

  # Shares the same Ollama concurrency key as RemediateAltTextJob so the combined
  # in-flight request count never exceeds OLLAMA_NUM_PARALLEL across both job types.
  include GoodJob::ActiveJobExtensions::Concurrency
  good_job_control_concurrency_with(
    total_limit: -> { ENV.fetch('OLLAMA_NUM_PARALLEL', 3).to_i },
    key: 'ollama_remediation'
  )

  # Uses VisionService to generate alt_text for image FileSets that have no description text.
  # Only runs when description is blank — records with description are handled by RemediateAltTextJob.
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
    return if file_set.description.present?

    summary = VisionService.call(file_set)
    if summary.present?
      file_set.alt_text = [summary]
      Hyrax.persister.save(resource: file_set)
      Hyrax.index_adapter.save(resource: file_set)
      Rails.logger.info("[AiDescriptionJob] Vision alt text set for FileSet #{file_set_id}")
    end
  rescue StandardError => e
    Rails.logger.tagged('AI_REMEDIATION_FAILURE') do
      Rails.logger.error("[AiDescriptionJob] file_set_id=#{file_set_id}, error=#{e.class}: #{e.message}")
    end
  end
end
