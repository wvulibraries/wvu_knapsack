# frozen_string_literal: true

module CatalogControllerDecorator
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
      # - label: auto-generate human-readable label if missing
      config.facet_fields.each do |field_name, facet_config|
        next if field_name.to_s == 'generic_type_sim'  # skip removed Type facet

        # Set limit and show_more for ALL facets — works for both pre-registered
        # and those added later by flexible metadata
        facet_config.limit = 5
        facet_config.show_more = true if facet_config.respond_to?(:show_more=)

        # Generate a friendly label if it's missing or matches the Solr field name
        current_label = facet_config.respond_to?(:label) ? facet_config.label : nil
        next if current_label.present? && current_label.to_s != field_name.to_s

        # Create a human-readable label from the Solr field name
        # e.g., "date_created_sim" → "Date Created", "creator_sim" → "Creator"
        humanized_label = field_name.to_s
                                   .gsub(/_sim$|_ssim$|_tesim$/, '')  # Remove Solr suffixes
                                   .gsub(/_label/, '')                 # Remove label suffix
                                   .gsub(/_/, ' ')                     # Convert underscores to spaces
                                   .titleize                           # Capitalize each word
        facet_config.label = humanized_label
      end
    end
  rescue NameError, LoadError
    # Skip if Wings or other dependencies not yet initialized
  end
end

# Apply the decorator to the actual controller
::CatalogController.prepend(CatalogControllerDecorator)
