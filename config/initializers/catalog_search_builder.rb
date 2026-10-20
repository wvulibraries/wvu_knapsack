# frozen_string_literal: true

# OVERRIDE: Set CatalogController to use CatalogSearchBuilder (not AdvSearchBuilder)
# This ensures facet.limit+1 is applied to ALL facets in catalog searches,
# enabling Blacklight to detect and display "more" links when there are more facet values.

Rails.application.config.to_prepare do
  # Override the CatalogController's search_builder_class configuration
  # The hyrax-webapp's CatalogController defaults to AdvSearchBuilder, but we need
  # CatalogSearchBuilder which enforces facet.limit+1 for proper "more" link detection
  
  Rails.logger.warn("CatalogSearchBuilder Initializer: to_prepare block executing")
  
  if Object.const_defined?('CatalogController')
    Rails.logger.warn("CatalogSearchBuilder Initializer: CatalogController is defined")
    CatalogController.configure_blacklight do |config|
      config.search_builder_class = ::CatalogSearchBuilder
      Rails.logger.warn("CatalogSearchBuilder Initializer: search_builder_class set to #{config.search_builder_class}")
    end
    
    Rails.logger.warn("CatalogSearchBuilder: Configured CatalogController to use ::CatalogSearchBuilder")
  else
    Rails.logger.warn("CatalogSearchBuilder Initializer: CatalogController NOT defined yet!")
  end
end
