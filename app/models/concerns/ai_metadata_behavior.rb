# frozen_string_literal: true

# AiMetadataBehavior is intentionally minimal — the scheduling logic lives in
# Hyrax::Listeners::AiMetadataListener (registered in
# config/initializers/ai_metadata_listener.rb), which hooks into the
# 'file.characterized' Hyrax event published after every upload.
#
# Valkyrie resources (Hyrax::FileSet) do not support ActiveRecord/ActiveFedora
# lifecycle callbacks (after_create, after_save, etc.) — do not add them here.
module AiMetadataBehavior
  extend ActiveSupport::Concern
end
