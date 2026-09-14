# frozen_string_literal: true

# Knapsack override: enforce facet limits on catalog searches
# Extends AdvSearchBuilder (the actual search builder used by the catalog)
# Ensures Solr receives f.<field>.facet.limit parameters set to limit+1
# This allows Blacklight to detect when there are more facet values and show "more" link
class CatalogSearchBuilder < AdvSearchBuilder
  def add_facetting_to_solr(solr_params)
    # Call parent to set up base faceting
    super
    
    # CRITICAL: Override facet limits to match Blacklight configuration for ALL facets
    # Solr MUST return limit+1 items so Blacklight can detect the "more" link
    # Example: If limit=5, request 6 from Solr. If Solr returns 6, show "more" link.
    if blacklight_config.respond_to?(:facet_fields)
      blacklight_config.facet_fields.each do |field_name, facet_config|
        limit = facet_config.limit || blacklight_config.default_facet_limit || 5
        facet_limit_value = (limit + 1).to_i
        # MUST be limit+1 for "more" link detection: limit=5 → request 6 from Solr
        solr_params["f.#{field_name}.facet.limit"] = facet_limit_value
      end
    end
    
    solr_params
  end
end

