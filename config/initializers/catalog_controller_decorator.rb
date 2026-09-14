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

    # Dynamically register M3 flexible-metadata facets
    # Strategy: Try Hyrax schema first (running systems), fall back to YAML file (fresh boot)
    # 
    # Why this matters:
    # 1. On running systems: reads ACTIVE profile from Hyrax schema database
    # 2. On fresh boot/docker reset: falls back to YAML file (schema table not populated yet)
    # 3. Adapts to profile changes automatically when profiles are loaded via Hyrax UI
    properties = {}
    
    begin
      # Try 1: Read from Hyrax::FlexibleSchema (for running systems with active profiles)
      schema = Hyrax::FlexibleSchema.current_version
      if schema.present?
        json_schema = schema.json_schema || {}
        properties = json_schema['properties'] || {}
        Rails.logger.info("Loaded facet properties from Hyrax::FlexibleSchema (#{properties.size} properties)")
      end
    rescue StandardError => e
      Rails.logger.debug("Hyrax::FlexibleSchema unavailable (#{e.message}); will try YAML fallback")
    end
    
    # Try 2: Fall back to YAML file if schema not available (fresh boot, migrations pending, etc.)
    if properties.empty?
      m3_profile_path = Rails.root.join('config', 'metadata_profiles', 'm3_profile.yaml')
      if File.exist?(m3_profile_path)
        begin
          m3_profile = YAML.safe_load(File.read(m3_profile_path))
          properties = m3_profile['properties'] || {} if m3_profile.is_a?(Hash)
          Rails.logger.info("Loaded facet properties from m3_profile.yaml (#{properties.size} properties)")
        rescue StandardError => e
          Rails.logger.warn("Error loading m3_profile.yaml: #{e.message}")
        end
      else
        Rails.logger.warn("m3_profile.yaml not found at #{m3_profile_path}")
      end
    end
    
    # Register facets from whichever source provided properties
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
        end
      end
      Rails.logger.info("Registered #{config.facet_fields.size} total facet fields")
    else
      Rails.logger.warn("No facet properties loaded; using default Blacklight facet configuration")
    end
  end
end

