# frozen_string_literal: true

# Apply facet limits dynamically to catch M3 flexible-metadata facets
# This runs after gems initialize but before each request, ensuring
# all facets (including late-registered M3 ones) have limit: 5 and show_more: true

Rails.application.config.to_prepare do
  next unless defined?(::CatalogController)
  
  ::CatalogController.configure_blacklight do |config|
    next unless config.respond_to?(:facet_fields) && config.facet_fields.is_a?(Hash)
    
    # Remove Type facet (Hyku #3072 workaround)
    config.facet_fields.delete('generic_type_sim') if config.facet_fields.key?('generic_type_sim')
    
    # Set default for any unspecified facets
    config.default_facet_limit = 5
    
    # Force limit: 5 on ALL facets (catches dynamically-registered M3 facets)
    # Use integer values (not true/false) for Solr compatibility
    config.facet_fields.each do |field_name, facet_config|
      next if field_name.to_s == 'generic_type_sim'  # Already deleted above
      
      # CRITICAL: Ensure limit is an integer (not boolean true from show_more)
      # This is crucial for the template logic: `limit = facet_field.limit || 5`
      # and for the search builder: `(limit + 1).to_i`
      facet_config.limit = 5.to_i  # Explicit integer conversion
      facet_config.show_more = true
      
      Rails.logger.debug("facet_limits.rb: Configured #{field_name} - limit: #{facet_config.limit}, show_more: #{facet_config.show_more}")
    end
  end
end
