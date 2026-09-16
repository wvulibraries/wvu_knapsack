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

    # Dynamically register M3 flexible-metadata facets from YAML metadata profile
    # Load from data/setup_files/metadata-profile-v.3.yml to ensure ALL facetable fields are registered
    # This is more reliable than Hyrax::FlexibleSchema which may not have all properties loaded
    
    begin
      profile_path = Rails.root.join('data', 'setup_files', 'metadata-profile-v.3.yml')
      if File.exist?(profile_path)
        profile_yaml = YAML.safe_load_file(profile_path) || {}
        properties = profile_yaml['properties'] || {}
        
        facet_count = 0
        if properties.is_a?(Hash) && properties.any?
          properties.each do |property_name, property_config|
            next unless property_config.is_a?(Hash)
            
            # Get the indexing array (contains field names like title_sim, title_tesim, facetable, etc.)
            indexing_fields = property_config['indexing']
            next unless indexing_fields.is_a?(Array)
            
            # Only process if this property is marked as facetable
            next unless indexing_fields.include?('facetable')
            
            # Find _sim fields (Blacklight facets)
            indexing_fields.each do |field|
              next unless field.to_s.end_with?('_sim')
              
              # Only add if not already configured
              next if config.facet_fields.key?(field)
              
              # Use property_name as label (human-readable)
              label = property_name.gsub('_', ' ').titleize
              config.add_facet_field field, label: label, limit: 5, show_more: true
              Rails.logger.debug("Registered M3 facet: #{field} (#{label}), limit: 5, show_more: true")
              facet_count += 1
            end
          end
          Rails.logger.info("Registered #{facet_count} M3 facetable fields from metadata-profile-v.3.yml")
          Rails.logger.info("Total facet fields now in config: #{config.facet_fields.size}")
        else
          Rails.logger.info("No properties found in metadata-profile-v.3.yml; using default facet configuration")
        end
      else
        Rails.logger.warn("Metadata profile not found at #{profile_path}; using default facet configuration")
      end
    rescue StandardError => e
      Rails.logger.warn("Error loading facets from metadata-profile-v.3.yml: #{e.message}")
    end
    
    # CRITICAL: Call this AFTER adding all M3 facets
    # This tells Blacklight to add ALL facet_fields to each Solr request
    # Without this, newly registered M3 facets won't appear in the facet.field parameter
    config.add_facet_fields_to_solr_request!
    Rails.logger.info("Called add_facet_fields_to_solr_request! - all #{config.facet_fields.size} facets will be included in Solr requests")
  end
end

