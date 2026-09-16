# frozen_string_literal: true

# Knapsack override: enforce facet limits on catalog searches
# Extends AdvSearchBuilder (the actual search builder used by the catalog)
# Ensures Solr receives f.<field>.facet.limit parameters set to limit+1
# This allows Blacklight to detect when there are more facet values and show "more" link
class CatalogSearchBuilder < AdvSearchBuilder
  def add_facetting_to_solr(solr_params)
    Rails.logger.info("=" * 80)
    Rails.logger.info("CatalogSearchBuilder#add_facetting_to_solr CALLED")
    Rails.logger.info("=" * 80)
    
    # Call parent to set up base faceting
    super
    
    # CRITICAL: Override facet limits to match Blacklight configuration for ALL facets
    # Solr MUST return limit+1 items so Blacklight can detect the "more" link
    # Example: If limit=5, request 6 from Solr. If Solr returns 6, show "more" link.
    if blacklight_config.respond_to?(:facet_fields)
      Rails.logger.info("CatalogSearchBuilder: blacklight_config.facet_fields present")
      Rails.logger.info("CatalogSearchBuilder: Total facets in config: #{blacklight_config.facet_fields.size}")
      
      facets_with_limits = []
      m3_facets = []
      
      blacklight_config.facet_fields.each do |field_name, facet_config|
        limit = facet_config.limit || blacklight_config.default_facet_limit || 5
        facet_limit_value = (limit + 1).to_i
        
        # MUST be limit+1 for "more" link detection: limit=5 → request 6 from Solr
        solr_params["f.#{field_name}.facet.limit"] = facet_limit_value
        facets_with_limits << "#{field_name}=#{facet_limit_value}"
        
        # Track M3 facets (those with _sim suffix that were dynamically registered)
        if field_name.end_with?('_sim') && 
          %w[date_created_sim location_sim people_represented_sim subject_sim 
             keyword_sim policy_area_sim key_topics_sim performance_media_sim 
             interviewer_sim interviewee_sim subject_mesh_sim].include?(field_name)
          m3_facets << field_name
        end
        
        Rails.logger.debug("  #{field_name}: limit=#{limit} → solr f.#{field_name}.facet.limit=#{facet_limit_value}")
      end
      
      Rails.logger.info("CatalogSearchBuilder: Configured #{blacklight_config.facet_fields.size} total facets")
      Rails.logger.info("CatalogSearchBuilder: M3 flexible-metadata facets: #{m3_facets.empty? ? 'NONE FOUND' : m3_facets.join(', ')}")
      Rails.logger.info("CatalogSearchBuilder: All facet.limit params set in Solr request")
    else
      Rails.logger.warn("CatalogSearchBuilder: ERROR - blacklight_config doesn't respond to :facet_fields")
    end
    
    Rails.logger.info("=" * 80)
    
    solr_params
  end
end

