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

    # Dynamically register M3 flexible-metadata facets from the ACTIVE metadata profile
    # Uses Hyrax::FlexibleSchema to get what's currently active (not static file in repo)
    # ONLY registers fields explicitly marked as facetable in the M3 profile
    
    m3_facets = {}
    
    # Try to load from active FlexibleSchema context (tenant's M3 profile)
    begin
      if Hyrax.config.flexible?
        # Get the CURRENT tenant's active schema - this is the active M3 profile
        # Use current_version if available (tenant-aware), fallback to last created
        schema = if defined?(Hyrax::FlexibleSchema) && Hyrax::FlexibleSchema.respond_to?(:current_version)
                   Hyrax::FlexibleSchema.current_version
                 else
                   Hyrax::FlexibleSchema.order("created_at asc").last
                 end
        
        if schema&.profile
          properties = schema.profile.dig('properties') || {}
          
          # Iterate all properties and ONLY register those marked as facetable
          properties.each do |property_name, property_def|
            next unless property_def.is_a?(Hash)
            
            # Get indexing array (contains field names like creator_sim, creator_tesim, facetable)
            indexing = property_def['indexing']
            next unless indexing.is_a?(Array)
            
            # ONLY register if explicitly marked as facetable
            next unless indexing.include?('facetable')
            
            # Find the _sim field for this property
            sim_field = indexing.find { |f| f.to_s.end_with?('_sim') }
            next unless sim_field
            
            # Skip if already configured in base Hyku config
            next if config.facet_fields.key?(sim_field)
            
            # Extract human-readable label, avoiding i18n keys
            # If display_label is a key like "blacklight.search.fields.show.xxx", use property name instead
            label = property_def.dig('display_label', 'en') || 
                    property_def.dig('display_label', 'default')
            
            # If label is an i18n key (starts with blacklight.), use human-readable property name
            if label.nil? || label.to_s.start_with?('blacklight.')
              label = property_name.gsub('_', ' ').titleize
            end
            
            m3_facets[sim_field] = label
            Rails.logger.debug("Found M3 facet: #{sim_field} => #{label}")
          end
          
          if m3_facets.any?
            Rails.logger.info("Registered #{m3_facets.size} M3 facets from active FlexibleSchema")
          else
            Rails.logger.warn("No facetable properties found in active FlexibleSchema")
          end
        else
          Rails.logger.warn("No active FlexibleSchema profile found")
        end
      else
        Rails.logger.warn("Flexible metadata not enabled (Hyrax.config.flexible? = false)")
      end
    rescue StandardError => e
      Rails.logger.warn("Error loading facets from FlexibleSchema: #{e.message}")
    end
    
    # Register all discovered M3 facets with Blacklight
    m3_facets.each do |field_name, label|
      # Skip if already configured (e.g., from hyrax-webapp base config)
      next if config.facet_fields.key?(field_name)
      
      config.add_facet_field field_name, label: label, limit: 5, show_more: true
      Rails.logger.debug("Registered M3 facet: #{field_name} => #{label}")
    end
    
    Rails.logger.info("Total M3 facets registered: #{m3_facets.size}")
  end
end

