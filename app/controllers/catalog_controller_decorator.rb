# frozen_string_literal: true

module CatalogControllerDecorator
  # Knapsack override of CatalogController for WVU customizations
  # Configures Blacklight facet settings and ensures custom search builder is used
  
  def self.apply
    ::CatalogController.configure_blacklight do |config|
      config.advanced_search[:form_facet_partial] = "advanced_search_facets"

      # Pagination settings
      config.per_page = [6, 12, 24, 48, 96]
      config.default_per_page = 12
      
      # CRITICAL: Set custom search builder to ensure facet limit params are sent to Solr
      config.search_builder_class = ::CatalogSearchBuilder
      
      # Hyku #3072: Hide Type facet (not needed for WVU theme)
      config.facet_fields.delete('generic_type_sim')
    end
  end
end

# Apply decorator immediately
CatalogControllerDecorator.apply

# CRITICAL: Prepend module to ensure it takes effect in method resolution order
::CatalogController.prepend(CatalogControllerDecorator)
