# frozen_string_literal: true

module CatalogControllerDecorator
  def search_builder_class
    CatalogSearchBuilder
  end

  # Configuration for CatalogController's Blacklight setup
  # This code runs when the decorator is loaded (in to_prepare)
  # Migrated from hyrax-webapp submodule changes — never modify submodule for customizations
  begin
    ::CatalogController.configure_blacklight do |config|
      config.advanced_search[:form_facet_partial] = "advanced_search_facets"

      # adjust pagination
      config.per_page = [6, 12, 24, 48, 96]
      config.default_per_page = 12

      next unless config.respond_to?(:facet_fields)
      next unless config.facet_fields.is_a?(Hash)

      # Hyku #3072 workaround: remove generic_type_sim (Type) facet — not needed for WVU theme
      config.facet_fields.delete('generic_type_sim') if config.facet_fields.key?('generic_type_sim')

      # Apply consistent settings to ALL visible facet fields:
      # - limit: 5 (show first 5 values)
      # - show_more: true (enable "More" link to fetch all values)
      # - label: ensure readable label exists (not Solr field name like "creator_sim")
      config.facet_fields.each do |field_name, facet_config|
        next if field_name.to_s == 'generic_type_sim'  # skip removed Type facet

        # Set limit and show_more for ALL facets
        facet_config.limit = 5
        facet_config.show_more = true

        # Add label if it's missing or matches the Solr field name (auto-generated)
        current_label = facet_config.respond_to?(:label) ? facet_config.label : nil
        next unless current_label.nil? || current_label.to_s == field_name.to_s

        case field_name.to_s
        when 'resource_type_sim'  then facet_config.label = "Resource Type"
        when 'creator_sim'        then facet_config.label = "Creator"
        when 'contributor_sim'    then facet_config.label = "Contributor"
        when 'keyword_sim'        then facet_config.label = "Keyword"
        when 'subject_sim'        then facet_config.label = "Subject"
        when 'language_sim'       then facet_config.label = "Language"
        when 'based_near_label_sim' then facet_config.label = "Location"
        when 'publisher_sim'      then facet_config.label = "Publisher"
        when 'file_format_sim'    then facet_config.label = "File Format"
        when 'contributing_library_sim' then facet_config.label = "Contributing Library"
        when 'member_of_collections_ssim' then facet_config.label = "Collections"
        end
      end
    end
  rescue NameError, LoadError
    # Skip if Wings or other dependencies not yet initialized
  end
end

::CatalogController.prepend(CatalogControllerDecorator)
