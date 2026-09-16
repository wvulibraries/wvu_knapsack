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
    # This allows users to upload/adjust M3 profiles without dev changes
    
    m3_facets = {}
    
    # Try to load from active FlexibleSchema context (DB/system loaded M3 profile)
    begin
      if Hyrax.config.flexible?
        # Get the current schema - this is the ACTIVE M3 profile in the system
        schema = Hyrax::FlexibleSchema.order("created_at asc").last
        
        if schema&.profile
          properties = schema.profile.dig('properties') || {}
          
          # Iterate all properties to find facetable ones
          properties.each do |property_name, property_def|
            next unless property_def.is_a?(Hash)
            
            # Get indexing array (contains field names like creator_sim, creator_tesim, facetable)
            indexing = property_def['indexing']
            next unless indexing.is_a?(Array) && indexing.include?('facetable')
            
            # Find the _sim field for this property
            sim_field = indexing.find { |f| f.to_s.end_with?('_sim') }
            next unless sim_field
            
            # Use property label or generate from name
            label = property_def.dig('display_label', 'default') || 
                    property_def.dig('display_label', 'en') ||
                    property_name.gsub('_', ' ').titleize
            m3_facets[sim_field] = label
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

