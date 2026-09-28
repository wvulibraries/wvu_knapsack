# frozen_string_literal: true

# OVERRIDE: Set CatalogController to use CatalogSearchBuilder (not AdvSearchBuilder)
# This ensures facet.limit+1 is applied to ALL facets in catalog searches,
# enabling Blacklight to detect and display "more" links when there are more facet values.

Rails.application.config.to_prepare do
  # Override the CatalogController's search_builder_class configuration
  # The hyrax-webapp's CatalogController defaults to AdvSearchBuilder, but we need
  # CatalogSearchBuilder which enforces facet.limit+1 for proper "more" link detection
  
  if Object.const_defined?('CatalogController')
    CatalogController.configure_blacklight do |config|
      config.search_builder_class = ::CatalogSearchBuilder
    end
    
    Rails.logger.info("CatalogSearchBuilder: Configured CatalogController to use ::CatalogSearchBuilder")
  end
end
