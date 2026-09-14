# frozen_string_literal: true

# Configure CatalogController to use our custom search builder
# This must run AFTER hyrax-webapp's catalog controller initializes
Rails.application.config.to_prepare do
  next unless defined?(::CatalogController)

  # Override the Blacklight configuration to use our custom search builder
  ::CatalogController.configure_blacklight do |config|
    # Set custom search builder that injects facet limit parameters
    config.search_builder_class = ::CatalogSearchBuilder

    # Advanced search facet partial
    config.advanced_search[:form_facet_partial] = "advanced_search_facets"

    # Pagination settings
    config.per_page = [6, 12, 24, 48, 96]
    config.default_per_page = 12

    # Hyku #3072: Hide Type facet (not needed for WVU theme)
    config.facet_fields.delete('generic_type_sim')
  end
end
