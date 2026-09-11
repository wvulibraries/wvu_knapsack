# frozen_string_literal: true

# Force facet limits on ALL facets, including those added by M3 flexible-metadata.
# This initializer runs AFTER Hyrax initialization, ensuring even late-registered
# facets get limit: 5 and show_more: true.

Rails.configuration.to_prepare do
  next unless defined?(CatalogController)

  CatalogController.configure_blacklight do |config|
    next unless config.respond_to?(:facet_fields)
    next unless config.facet_fields.is_a?(Hash)

    # Remove Type facet (Hyku #3072 workaround)
    config.facet_fields.delete('generic_type_sim') if config.facet_fields.key?('generic_type_sim')

    # Force limit: 5 and show_more: true on EVERY facet, including those
    # added by M3 flexible-metadata AFTER the decorator ran
    config.facet_fields.each do |field_name, facet_config|
      next if field_name.to_s == 'generic_type_sim'

      # Apply limit and show_more
      facet_config.limit = 5
      facet_config.show_more = true if facet_config.respond_to?(:show_more=)

      # Auto-generate friendly label if it's missing or matches the field name
      current_label = facet_config.respond_to?(:label) ? facet_config.label : nil
      next if current_label.present? && current_label.to_s != field_name.to_s

      # Humanize: strip Solr suffixes, convert underscores to spaces, titleize
      humanized_label = field_name.to_s
                                 .gsub(/_sim$|_ssim$|_tesim$|_label$/, '')
                                 .gsub(/_/, ' ')
                                 .titleize
      facet_config.label = humanized_label
    end
  end
rescue NameError, LoadError
  # Skip if CatalogController not yet loaded
end
