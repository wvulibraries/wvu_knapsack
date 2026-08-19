# frozen_string_literal: true

Rails.application.config.to_prepare do
  # Decorator for CatalogSearchBuilder to enforce facet limits
  module CatalogSearchBuilderDecorator
    def build(user_params = {})
      params = super
      
      # Override facet limits to match Blacklight configuration
      begin
        blacklight_config.facet_fields.each do |field_name, facet_config|
          limit = facet_config.limit || 5
          params[:"f.#{field_name}.facet.limit"] = limit
        end
      rescue StandardError => e
        Rails.logger.warn("CatalogSearchBuilderDecorator error: #{e.message}")
      end
      
      params
    end
  end
  
  # Apply to default Blacklight search builder if it exists
  search_builder_class = CatalogController.search_builder_class
  search_builder_class.prepend(CatalogSearchBuilderDecorator) unless search_builder_class.included_modules.include?(CatalogSearchBuilderDecorator)
end
