# frozen_string_literal: true

module CatalogControllerDecorator
  # Configuration for CatalogController's Blacklight setup
  # Migrated from hyrax-webapp submodule changes — never modify submodule for customizations

  # ========================================================================
  # 1. CONFIGURE FACETS AT BOOT TIME
  #    Sets limit and labels on all facets that exist at initialization
  # ========================================================================
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

      # Apply consistent settings to all facets present at boot
      config.facet_fields.each do |field_name, facet_config|
        next if field_name.to_s == 'generic_type_sim'

        facet_config.limit = 5
        facet_config.show_more = true if facet_config.respond_to?(:show_more=)

        # Generate friendly label if missing or is just the field name
        current_label = facet_config.respond_to?(:label) ? facet_config.label : nil
        next if current_label.present? && current_label.to_s != field_name.to_s

        # Dynamically create a human-readable label from the Solr field name
        # e.g., "date_created_sim" → "Date Created", "based_near_label_sim" → "Based Near"
        humanized_label = field_name.to_s
                                   .gsub(/_sim$|_ssim$|_tesim$|_label$/, '')  # Strip Solr suffixes
                                   .gsub(/_/, ' ')                             # Underscores → spaces
                                   .titleize                                   # Capitalize words
        facet_config.label = humanized_label
      end
    end
  rescue NameError, LoadError
    # Skip if dependencies not yet initialized
  end

  # ========================================================================
  # 2. FORCE FACET LIMITS AT REQUEST TIME (search_builder level)
  #    This ensures even facets added later by flexible-metadata get limit: 5
  # ========================================================================

  # Override search_builder_class to inject our facet-limit enforcement
  def search_builder_class
    CatalogControllerDecorator::FacetLimitingSearchBuilder
  end

  # Inner class: search builder that forces facet limits in Solr parameters
  class FacetLimitingSearchBuilder < Hyrax::CatalogSearchBuilder
    def build(user_params = {})
      params = super

      # For EVERY facet field that Blacklight knows about (including those
      # added by M3 flexible-metadata AFTER configuration), ensure Solr
      # gets facet.limit parameters
      blacklight_config.facet_fields.each do |field_name, facet_config|
        next if field_name.to_s == 'generic_type_sim'

        # Determine the limit: use what's in the config, default to 5
        limit = facet_config.limit || 5

        # Set the Solr parameter: f.<fieldname>.facet.limit
        params[:"f.#{field_name}.facet.limit"] = limit
      end

      params
    end
  end
end

# Apply the decorator to the actual controller
::CatalogController.prepend(CatalogControllerDecorator)
