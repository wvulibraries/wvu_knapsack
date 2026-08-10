# frozen_string_literal: true

module CatalogControllerDecorator
  # Configuration for CatalogController's Blacklight setup
  # This code runs when the decorator is loaded (in to_prepare)
  CatalogController.configure_blacklight do |config|
    config.advanced_search[:form_facet_partial] = "advanced_search_facets"
    
    # Hide Type facet from search sidebar (Hyku #3072 workaround)
    config.facet_fields.delete('generic_type_sim')
    
    # Add explicit labels to facet fields for consistent UI display
    # (Blacklight auto-generates labels from field names if not explicitly set,
    # resulting in "Creator Sim" instead of "Creator", etc.)
    config.facet_fields['creator_sim']&.label = "Creator"
    config.facet_fields['keyword_sim']&.label = "Keyword"
    config.facet_fields['subject_sim']&.label = "Subject"
    config.facet_fields['language_sim']&.label = "Language"
    config.facet_fields['based_near_label_sim']&.label = "Location"
    config.facet_fields['publisher_sim']&.label = "Publisher"
    config.facet_fields['file_format_sim']&.label = "File Format"
    config.facet_fields['contributing_library_sim']&.label = "Contributing Library"
  end
end
