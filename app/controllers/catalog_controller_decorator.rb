# frozen_string_literal: true

module CatalogControllerDecorator
  # Configuration for CatalogController's Blacklight setup
  # This code runs when the decorator is loaded (in to_prepare)
  # Migrated from hyrax-webapp submodule changes — never modify submodule for customizations
  CatalogController.configure_blacklight do |config|
    config.advanced_search[:form_facet_partial] = "advanced_search_facets"

    # adjust pagination
    config.per_page = [6, 12, 24, 48, 96]
    config.default_per_page = 12

    # Hyku #3072 workaround: remove generic_type_sim (Type) facet — not needed for WVU theme
    config.facet_fields.delete('generic_type_sim') if config.facet_fields.key?('generic_type_sim')

    # Add show_more: true to all visible facets so "More" links fetch ALL values (not just limit:5)
    # This fixes the issue where modal boxes only showed first 5 results
    facet_fields_to_update = %w[
      resource_type_sim
      creator_sim
      contributor_sim
      keyword_sim
      subject_sim
      language_sim
      based_near_label_sim
      publisher_sim
      file_format_sim
      contributing_library_sim
      member_of_collections_ssim
    ]

    facet_fields_to_update.each do |field_name|
      next unless config.facet_fields.key?(field_name)

      config.facet_fields[field_name].limit = 5
      config.facet_fields[field_name].show_more = true
    end
  end
end
