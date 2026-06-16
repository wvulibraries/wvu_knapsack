# frozen_string_literal: true

module CatalogControllerDecorator
  # Configuration for CatalogController's Blacklight setup
  # This code runs when the decorator is loaded (in to_prepare)
  CatalogController.configure_blacklight do |config|
    config.advanced_search[:form_facet_partial] = "advanced_search_facets"

    # adjust pagination
    config.per_page = [6, 12, 24, 48, 96]
    config.default_per_page = 12    
  end
end
