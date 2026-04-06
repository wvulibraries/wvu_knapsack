# frozen_string_literal: true

module Hyrax
  module Listeners
    # Listens for the 'file.characterized' Hyrax event and enqueues AI alt-text
    # remediation jobs for images and PDFs that are missing alt_text.
    #
    # Registered via config/initializers/ai_metadata_listener.rb.
    #
    # Event payload (Valkyrie path):
    #   event[:file_set] — Hyrax::FileSet resource
    #   event[:file_id]  — FileMetadata id (String)
    class AiMetadataListener
      # Called when 'file.characterized' is published by
      # Hyrax::Characterization::ValkyrieCharacterizationService.
      #
      # @param [Dry::Events::Event] event
      # @return [void]
      def on_file_characterized(event)
        return unless ENV['AI_ENABLED'] == 'true'

        file_set = event[:file_set]
        # Only handle the Valkyrie path; ActiveFedora FileSets are handled elsewhere.
        return unless file_set.is_a?(Hyrax::FileSet)
        return unless file_set.alt_text.blank?

        # Look up the FileMetadata to get the mime_type that was just set.
        file_metadata = Hyrax.custom_queries.find_file_metadata_by(
          id: Valkyrie::ID.new(event[:file_id])
        )
        # Only act on the original file, not thumbnails or extracted text.
        return unless file_metadata&.original_file?

        mime = file_metadata.mime_type.to_s

        if mime == 'application/pdf'
          OcrPdfJob.perform_later(file_set.id.to_s)
        elsif mime.start_with?('image') && file_set.description.present?
          RemediateAltTextJob.perform_later(file_set.id.to_s)
        elsif mime.start_with?('image')
          AiDescriptionJob.perform_later(file_set.id.to_s)
        end
      rescue StandardError => e
        Rails.logger.tagged('AI_REMEDIATION_FAILURE') do
          Rails.logger.error("[AiMetadataListener] FileSet #{file_set&.id}: #{e.class}: #{e.message}")
        end
      end
    end
  end
end
