# typed: strict

require 'base64'
require 'faraday'
require 'json'

class VisionService
  OLLAMA_URL   = ENV.fetch('OLLAMA_URL', 'http://ollama:11434/api/generate')
  OLLAMA_MODEL = ENV.fetch('OLLAMA_MODEL', 'moondream')
  PROMPT = 'Briefly describe what is shown in this image in one concise sentence under 125 characters.'

  # Only MIME types Moondream/LLaVA can accept as base64 image input.
  SUPPORTED_MIME_TYPES = %w[
    image/jpeg
    image/png
    image/gif
    image/webp
    image/tiff
  ].freeze

  # Performs vision analysis on an image FileSet using Ollama's multimodal API.
  # Supports both Valkyrie (Hyrax::FileSet) and ActiveFedora (FileSet) resources.
  # For PDFs, use PdfAccessibilityService which calls call_with_bytes after rasterization.
  #
  # @param file_set [Hyrax::FileSet, FileSet] must be an image type (not PDF)
  # @return [String, nil] sanitized AI-generated alt text, or nil on error/unsupported type
  def self.call(file_set)
    if file_set.is_a?(Hyrax::FileSet)
      # Valkyrie path
      file_metadata = Hyrax.custom_queries.find_original_file(file_set: file_set)
      unless file_metadata
        Rails.logger.warn("[VisionService] No original file metadata for FileSet #{file_set.id}")
        return nil
      end

      mime = file_metadata.mime_type.to_s
      unless SUPPORTED_MIME_TYPES.include?(mime)
        Rails.logger.warn("[VisionService] Unsupported MIME '#{mime}' for FileSet #{file_set.id} — skipping")
        return nil
      end

      storage_file = Valkyrie::StorageAdapter.find_by(id: file_metadata.file_identifier)
      unless storage_file
        Rails.logger.warn("[VisionService] No stored file for FileSet #{file_set.id}")
        return nil
      end

      call_with_bytes(storage_file.read, file_set.id)
    else
      # ActiveFedora fallback path
      mime = file_set.mime_type.to_s
      unless SUPPORTED_MIME_TYPES.include?(mime)
        Rails.logger.warn("[VisionService] Unsupported MIME '#{mime}' for FileSet #{file_set.id} — skipping")
        return nil
      end

      content = file_set.original_file&.content
      unless content.present?
        Rails.logger.warn("[VisionService] No original file content for FileSet #{file_set.id} — file not yet attached")
        return nil
      end

      call_with_bytes(content, file_set.id)
    end
  end

  # Shared Ollama multimodal call used by both call() and PdfAccessibilityService.
  # Accepts raw image bytes (JPEG, PNG, etc.) — not PDF bytes.
  #
  # @param image_bytes [String] raw binary image content
  # @param context_id [String, Integer] FileSet id or other identifier for logging
  # @return [String, nil]
  def self.call_with_bytes(image_bytes, context_id = 'unknown')
    body = {
      model:  OLLAMA_MODEL,
      prompt: PROMPT,
      images: [Base64.strict_encode64(image_bytes)],
      stream: false
    }.to_json

    conn = Faraday.new do |f|
      f.options.open_timeout = ENV.fetch('OLLAMA_OPEN_TIMEOUT', 10).to_i
      f.options.timeout      = ENV.fetch('OLLAMA_READ_TIMEOUT', 45).to_i
    end

    response = conn.post(OLLAMA_URL, body, 'Content-Type' => 'application/json')
    raw = JSON.parse(response.body)['response']&.strip
    raw.present? ? AltTextGeneratorService::SanitizeAltText.call(raw) : nil
  rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
    Rails.logger.tagged('AI_REMEDIATION_FAILURE') { Rails.logger.error("[VisionService] #{e.class} for #{context_id}: #{e.message}") }
    nil
  rescue JSON::ParserError => e
    Rails.logger.error("[VisionService] JSON parse error for #{context_id}: #{e.message}")
    nil
  rescue StandardError => e
    Rails.logger.error("[VisionService] Error for #{context_id}: #{e.message}")
    nil
  end
end
