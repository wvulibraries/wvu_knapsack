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

    # Dynamically register M3 flexible-metadata facets from profile
    # Reads m3_profile.yaml and auto-registers all _sim fields as facets
    # This is future-proof: if M3 adds new facets, they're automatically registered
    m3_profile_path = Rails.root.join('config', 'metadata_profiles', 'm3_profile.yaml')
    if File.exist?(m3_profile_path)
      begin
        m3_profile = YAML.safe_load(File.read(m3_profile_path))
        
        # Extract all properties from the profile
        if m3_profile.is_a?(Hash) && m3_profile['properties'].is_a?(Hash)
          m3_profile['properties'].each do |property_name, property_config|
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
        end
        Rails.logger.info("Registered #{config.facet_fields.size} facet fields from M3 profile")
      rescue StandardError => e
        Rails.logger.warn("Error loading M3 profile: #{e.message}")
      end
    end
  end
end

