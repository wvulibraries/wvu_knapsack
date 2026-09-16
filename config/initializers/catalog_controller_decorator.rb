# frozen_string_literal: true

# Configure CatalogController to use our custom search builder
# This must run AFTER hyrax-webapp's catalog controller initializes
Rails.application.config.to_prepare do
  next unless defined?(::CatalogController)

  # Override the Blacklight configuration to use our custom search builder
  ::CatalogController.configure_blacklight do |config|
    # Set custom search builder that injects facet limit parameters
    config.search_builder_class = ::CatalogSearchBuilder

    # Advanced search facet partial
    config.advanced_search[:form_facet_partial] = "advanced_search_facets"

    # Pagination settings
    config.per_page = [6, 12, 24, 48, 96]
    config.default_per_page = 12

    # Hyku #3072: Hide Type facet (not needed for WVU theme)
    config.facet_fields.delete('generic_type_sim')

    # Dynamically register M3 flexible-metadata facets from Hyrax's active schema
    # 
    # Why this approach:
    # - Hyrax::FlexibleSchema.current_version reads the ACTIVE profile from PostgreSQL
    # - Users can upload/switch profiles (v.2, v.3, etc.) via web UI → stored in DB
    # - This ensures we always register facets from the ACTIVE profile, never stale data
    # - No YAML fallback: Safer to have no facets than wrong facets from old profile
    # 
    # Timing note:
    # - On fresh boot: Schema table may be empty initially → no facets (graceful)
    # - After migrations run: Schema populates → facets auto-register (by next request)
    # - This is fine because catalog is not used until schema is ready
    
    begin
      schema = Hyrax::FlexibleSchema.current_version
      if schema.present?
        json_schema = schema.json_schema || {}
        properties = json_schema['properties'] || {}
        
        if properties.is_a?(Hash) && properties.any?
          properties.each do |property_name, property_config|
            next unless property_config.is_a?(Hash)
            
            # Get the indexing array (contains field names like title_sim, title_tesim, etc.)
            indexing_fields = property_config['indexing']
            next unless indexing_fields.is_a?(Array)
            
            # Find _sim fields (Blacklight facets)
            indexing_fields.each do |field|
              next unless field.to_s.end_with?('_sim')
              
              # Only add if not already configured
              next if config.facet_fields.key?(field)
              
              # Use property_name as label (human-readable)
              label = property_name.gsub('_', ' ').titleize
              config.add_facet_field field, label: label, limit: 5, show_more: true
              Rails.logger.debug("Registered M3 facet: #{field} (#{label}), limit: 5, show_more: true")
            end
          end
          Rails.logger.info("Registered #{config.facet_fields.size} facet fields from active M3 schema")
        else
          Rails.logger.info("No properties found in active schema; using default facet configuration")
        end
      else
        Rails.logger.debug("Hyrax::FlexibleSchema not yet available (fresh boot); facets will register once schema loads")
      end
    rescue StandardError => e
      Rails.logger.warn("Error loading facets from schema: #{e.message}")
    end
  end
end

