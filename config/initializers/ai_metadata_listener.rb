# frozen_string_literal: true

# Register the AI alt-text remediation listener with Hyrax's event bus.
# It hooks into 'file.characterized' — fired after every upload is characterized —
# so jobs are enqueued only once mime_type is known and confirmed.
Rails.application.reloader.to_prepare do
  Hyrax.publisher.subscribe(Hyrax::Listeners::AiMetadataListener.new)
end
