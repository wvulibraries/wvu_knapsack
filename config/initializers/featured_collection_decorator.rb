# frozen_string_literal: true

Rails.application.config.to_prepare do
  module FeaturedCollectionDecorator
    extend ActiveSupport::Concern

    class_methods do
      def feature_limit
        15
      end
    end
  end

  FeaturedCollection.prepend(FeaturedCollectionDecorator)
end
