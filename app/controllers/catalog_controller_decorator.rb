# frozen_string_literal: true

module CatalogControllerDecorator
  # Configuration for CatalogController's Blacklight setup
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

      # Explicitly register M3 flexible-metadata facets if not already present
      # These may not be in the boot-time config but are indexed by Solr
      m3_facets = {
        'date_created_sim' => 'Date Created',
        'people_represented_sim' => 'People Represented'
      }
      m3_facets.each do |field_name, label|
        next if config.facet_fields.key?(field_name)
        config.add_facet_field field_name, label: label, limit: 5
      end

      # Apply consistent settings to ALL facets (both pre-registered and M3)
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
  # Override search_results to slice facet items after Solr response
  # This ensures ALL facets (even late-registered M3 flexible-metadata ones)
  # show only 5 items in the sidebar, regardless of config state
  # ========================================================================

  def search_results
    # Call the original search_results method from the parent class
    @response = super

    # Debug: Log what we're working with
    Rails.logger.info "=== CatalogControllerDecorator.search_results DEBUG ==="
    Rails.logger.info "Blacklight facet_fields: #{blacklight_config.facet_fields.keys}"
    Rails.logger.info "Solr facets returned: #{@response.facets.map(&:name)}"

    # Slice facet items to their configured limits (default 5)
    @response.facets.each do |facet|
      facet_config = blacklight_config.facet_fields[facet.name]
      next unless facet_config
      next if facet.name.to_s == 'generic_type_sim'

      # Get the limit (use config, default to 5)
      limit = facet_config.limit || 5
      original_count = facet.items.length

      # Slice the items if there are more than the limit
      if facet.items.respond_to?(:length) && facet.items.length > limit
        facet.items = facet.items.first(limit)
        Rails.logger.info "  #{facet.name}: sliced from #{original_count} to #{limit}"
      else
        Rails.logger.info "  #{facet.name}: #{original_count} items (no slicing needed)"
      end
    end

    @response
  end
end

# Apply the decorator to CatalogController
::CatalogController.prepend(CatalogControllerDecorator)
