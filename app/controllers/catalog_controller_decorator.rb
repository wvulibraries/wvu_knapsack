# frozen_string_literal: true

require 'wings/model_registry' if defined?(Wings)

module CatalogControllerDecorator
  # Configuration for CatalogController's Blacklight setup
  # This code runs when the decorator is loaded (in to_prepare)
  # Migrated from hyrax-webapp submodule changes — never modify submodule for customizations
  ::CatalogController.configure_blacklight do |config|
    config.advanced_search[:form_facet_partial] = "advanced_search_facets"

    # adjust pagination
    config.per_page = [6, 12, 24, 48, 96]
    config.default_per_page = 12

    # Hyku #3072 workaround: remove generic_type_sim (Type) facet — not needed for WVU theme
    config.facet_fields.delete('generic_type_sim') if config.facet_fields.key?('generic_type_sim')

    # Add labels + show_more: true to all visible facets so "More" links fetch ALL values
    next unless respond_to?(:facet_fields) && facet_fields.is_a?(Hash)

    facet_config = {
      resource_type_sim: { label: "Resource Type" },
      creator_sim:       { label: "Creator" },
      contributor_sim:   { label: "Contributor" },
      keyword_sim:       { label: "Keyword" },
      subject_sim:       { label: "Subject" },
      language_sim:      { label: "Language" },
      based_near_label_sim: { label: "Location" },
      publisher_sim:     { label: "Publisher" },
      file_format_sim:   { label: "File Format" },
      contributing_library_sim: { label: "Contributing Library" },
      member_of_collections_ssim: { label: "Collections" }
    }

    facet_config.each do |field_name, opts|
      next unless config.facet_fields.key?(field_name)

      config.facet_fields[field_name].label = opts[:label]
      config.facet_fields[field_name].limit = 5
      config.facet_fields[field_name].show_more = true
    end
  end
end
