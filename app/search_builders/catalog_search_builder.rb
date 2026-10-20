# frozen_string_literal: true

# Knapsack override: enforce facet limits on catalog searches
# Extends AdvSearchBuilder (the actual search builder used by the catalog)
# Ensures Solr receives f.<field>.facet.limit parameters for all facets
# This is necessary to limit facet response counts (default Solr limit is 100)
class CatalogSearchBuilder < AdvSearchBuilder
  def add_facetting_to_solr(solr_params)
    Rails.logger.warn("CatalogSearchBuilder#add_facetting_to_solr: METHOD CALLED!")
    
    # Call parent to set up base faceting
    super
    
    # Override facet limits to match Blacklight configuration for ALL facets
    # Ensures Solr returns only the configured number of values (usually 5)
    # Blacklight uses limit+1 to detect "more" link in UI
    if blacklight_config.respond_to?(:facet_fields)
      Rails.logger.warn("CatalogSearchBuilder#add_facetting_to_solr: Processing #{blacklight_config.facet_fields.size} facet fields")
      
      blacklight_config.facet_fields.each do |field_name, facet_config|
        # Get limit, handling cases where it might be Boolean or non-Integer
        limit = facet_config.limit if facet_config.respond_to?(:limit) && facet_config.limit.is_a?(Integer) && facet_config.limit > 0
        limit ||= blacklight_config.default_facet_limit || 5
        limit = limit.to_i  # Ensure it's always an integer
        
        # Set to limit+1 so Blacklight can detect if there are more results
        solr_params["f.#{field_name}.facet.limit"] = (limit + 1).to_i
        
        # Log specific critical fields
        if ['people_represented_sim', 'location_sim', 'date_created_sim'].include?(field_name)
          Rails.logger.info("CatalogSearchBuilder: Setting #{field_name} facet.limit = #{(limit + 1).to_i}")
        end
      end
      
      # Log the final Solr params for verification
      facet_limit_params = solr_params.select { |k, v| k.to_s.include?('facet.limit') }
      Rails.logger.info("CatalogSearchBuilder: Final facet.limit params: #{facet_limit_params.inspect}")
    else
      Rails.logger.warn("CatalogSearchBuilder: blacklight_config does not respond_to :facet_fields")
    end
    
    solr_params
  end
end
