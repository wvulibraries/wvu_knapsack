# frozen_string_literal: true

# Knapsack override: enforce facet limits on catalog searches
# Extends AdvSearchBuilder (the actual search builder used by the catalog)
# Ensures Solr receives f.<field>.facet.limit parameters for all facets
# This is necessary to limit facet response counts (default Solr limit is 100)
class CatalogSearchBuilder < AdvSearchBuilder
  def add_facetting_to_solr(solr_params)
    # Call parent to set up base faceting
    super
    
    # Override facet limits to match Blacklight configuration for ALL facets
    # Ensures Solr returns only the configured number of values (usually 5)
    # Blacklight uses limit+1 to detect "more" link in UI
    if blacklight_config.respond_to?(:facet_fields)
      blacklight_config.facet_fields.each do |field_name, facet_config|
        limit = facet_config.limit || blacklight_config.default_facet_limit || 5
        # Set to limit+1 so Blacklight can detect if there are more results
        solr_params["f.#{field_name}.facet.limit"] = (limit + 1).to_i
      end
    end
    
    solr_params
  end
end
