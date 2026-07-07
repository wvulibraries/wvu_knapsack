# frozen_string_literal: true

module CatalogControllerDecorator
  # Configuration for CatalogController's Blacklight setup
  # This code runs when the decorator is loaded (in to_prepare)
  CatalogController.configure_blacklight do |config|
    config.advanced_search[:form_facet_partial] = "advanced_search_facets"
    
    # Hide Type facet from search sidebar (Hyku #3072 workaround)
    config.facet_fields.delete('generic_type_sim')
  end
end
