# frozen_string_literal: true

# GoodJob configuration for AI remediation workload.
# This runs AFTER the submodule's good_job.rb (alphabetical load order).
# Overrides the queue list and adds AI-specific priority + concurrency.
#
# Tuning knobs (set in .env on the Dev VM):
#   OLLAMA_NUM_PARALLEL  — how many requests Ollama handles in parallel (default: 3)
#   OLLAMA_READ_TIMEOUT  — max inference seconds per image, used to size shutdown_timeout (default: 45)

if ENV.fetch('HYRAX_ACTIVE_JOB_QUEUE', 'sidekiq') == 'good_job'
  Rails.application.configure do
    # Cap the ai_remediation queue to OLLAMA_NUM_PARALLEL threads.
    # Adding more threads than Ollama's parallel slots just piles up idle DB connections.
    # Format: 'queue_name:max_threads;...' — '*' catches all remaining queues.
    ai_threads = ENV.fetch('OLLAMA_NUM_PARALLEL', 3).to_i
    config.good_job.queues = "ai_remediation:#{ai_threads};*"

    # Shutdown timeout must exceed the Faraday read timeout set in AltTextGeneratorService
    # so GoodJob does not kill a mid-inference thread. OLLAMA_READ_TIMEOUT defaults to 45s.
    config.good_job.shutdown_timeout = ENV.fetch('OLLAMA_READ_TIMEOUT', 45).to_i + 30
  end

  Rails.application.config.after_initialize do
    # Priority: lower number = lower priority in GoodJob.
    # Run AI jobs after ALL ingest and derivative jobs are complete so they do not
    # compete for disk I/O with CharacterizeJob (30) / CreateDerivativesJob (40).
    #
    # OcrPdfJob runs at -28 (slightly ahead of -30) so the OCR text layer is in
    # place before RemediatePdfJob attempts pdftotext extraction.
    OcrPdfJob.priority           = -28
    RemediateAltTextJob.priority = -30
    AiDescriptionJob.priority    = -30
    RemediatePdfJob.priority     = -30
  end
end
