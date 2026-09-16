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
    # This allows users to add new facetable fields without code changes
    # Fallback to hardcoded list if YAML parsing fails
    
    m3_facets = {}
    
    # Hardcoded core facets (fallback if YAML parsing fails)
    core_facets = {
      'creator_sim' => 'Creator',
      'date_created_sim' => 'Date Created',
      'based_near_label_sim' => 'Location',
      'location_sim' => 'Location',
      'people_represented_sim' => 'People Represented',
      'keyword_sim' => 'Keyword',
      'subject_sim' => 'Subject',
      'publisher_sim' => 'Publisher',
      'policy_area_sim' => 'Policy Area',
      'key_topics_sim' => 'Key Topics',
      'performance_media_sim' => 'Performance Media',
      'interviewer_sim' => 'Interviewer',
      'interviewee_sim' => 'Interviewee',
      'subject_mesh_sim' => 'Subject (MeSH)',
      'repository_sim' => 'Repository'
    }
    
    # Try to load dynamic facets from metadata profile YAML
    begin
      profile_path = Rails.root.join('data', 'setup_files', 'metadata-profile-v.3.yml')
      if File.exist?(profile_path)
        profile_yaml = YAML.safe_load_file(profile_path) || {}
        properties = profile_yaml['properties'] || {}
        
        if properties.is_a?(Hash) && properties.any?
          properties.each do |property_name, property_config|
            next unless property_config.is_a?(Hash)
            
            # Get indexing array (contains field names like creator_sim, creator_tesim, facetable)
            indexing = property_config['indexing']
            next unless indexing.is_a?(Array) && indexing.include?('facetable')
            
            # Find _sim field for this property
            sim_field = indexing.find { |f| f.to_s.end_with?('_sim') }
            next unless sim_field
            
            # Generate human-readable label from property name
            label = property_name.gsub('_', ' ').titleize
            m3_facets[sim_field] = label
          end
          Rails.logger.debug("Dynamically loaded #{m3_facets.size} M3 facets from metadata profile YAML")
        end
      else
        Rails.logger.warn("Metadata profile not found at #{profile_path}; using fallback facet list")
      end
    rescue StandardError => e
      Rails.logger.warn("Error loading facets from metadata YAML: #{e.message}; using fallback facet list")
    end
    
    # Use dynamic facets if we found any, otherwise use hardcoded fallback
    m3_facets = core_facets if m3_facets.empty?
    
    # Register all M3 facets with Blacklight
    m3_facets.each do |field_name, label|
      # Skip if already configured (e.g., from hyrax-webapp base config)
      next if config.facet_fields.key?(field_name)
      
      config.add_facet_field field_name, label: label, limit: 5, show_more: true
      Rails.logger.debug("Registered M3 facet: #{field_name} => #{label}")
    end
    
    Rails.logger.info("Registered #{m3_facets.size} M3 flexible-metadata facet fields")
  end
end

