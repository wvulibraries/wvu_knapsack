# typed: strict

module AiMetadataBehavior
  extend ActiveSupport::Concern

  included do
    after_create_commit :enqueue_alt_text_remediation, if: :ai_alt_text_needed?
  end

  private

  def ai_alt_text_needed?
    (image? || pdf?) && alt_text.blank?
  end

  def enqueue_alt_text_remediation
    if pdf?
      # PDFs always enter the OCR pipeline first so the file stored in Fedora gets
      # an embedded text layer regardless of whether a description is present.
      # OcrPdfJob cascades to RemediatePdfJob which generates alt_text from:
      #   - the embedded text layer (after OCR), or
      #   - the description field (if present and text extraction yields nothing), or
      #   - Moondream vision fallback (last resort for image-only PDFs).
      OcrPdfJob.perform_later(self.id)
    elsif description.present?
      # Non-PDF with text metadata: summarise it into alt_text
      RemediateAltTextJob.perform_later(self.id)
    elsif image?
      # Image with no description: ask the vision model to look at it
      AiDescriptionJob.perform_later(self.id)
    end
  end

  # Placeholder methods for type detection
  def image?
    # Implement logic to check if FileSet is an image
    mime_type&.start_with?('image')
  end

  def pdf?
    # Implement logic to check if FileSet is a PDF
    mime_type == 'application/pdf'
  end
end
