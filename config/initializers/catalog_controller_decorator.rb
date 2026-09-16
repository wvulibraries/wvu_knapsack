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

    # Register M3 flexible-metadata facets explicitly
    # These facets are in Solr but not auto-added to blacklight_config
    # Must explicitly configure them for Blacklight to show "more" links
    m3_facets = {
      'date_created_sim' => { label: 'Date Created', limit: 5, show_more: true },
      'based_near_label_sim' => { label: 'Location', limit: 5, show_more: true },
      'people_represented_sim' => { label: 'People Represented', limit: 5, show_more: true },
      'location_sim' => { label: 'Location', limit: 5, show_more: true },
      'keyword_sim' => { label: 'Keyword', limit: 5, show_more: true },
      'subject_sim' => { label: 'Subject', limit: 5, show_more: true },
      'publisher_sim' => { label: 'Publisher', limit: 5, show_more: true },
      'policy_area_sim' => { label: 'Policy Area', limit: 5, show_more: true },
      'key_topics_sim' => { label: 'Key Topics', limit: 5, show_more: true },
      'performance_media_sim' => { label: 'Performance Media', limit: 5, show_more: true },
      'interviewer_sim' => { label: 'Interviewer', limit: 5, show_more: true },
      'interviewee_sim' => { label: 'Interviewee', limit: 5, show_more: true },
      'subject_mesh_sim' => { label: 'Subject (MeSH)', limit: 5, show_more: true },
      'repository_sim' => { label: 'Repository', limit: 5, show_more: true }
    }

    m3_facets.each do |field_name, facet_config|
      # Only add if not already configured
      next if config.facet_fields.key?(field_name)
      config.add_facet_field field_name, facet_config
      Rails.logger.debug("Registered M3 facet: #{field_name} with config: #{facet_config}")
    end
    Rails.logger.info("Registered #{m3_facets.size} M3 flexible-metadata facet fields")
  end
end

