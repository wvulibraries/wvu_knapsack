# frozen_string_literal: true

# Knapsack override: enforce facet limits on catalog searches
# Limits facet results returned from Solr to configured limit (default 5)
class CatalogSearchBuilder < Blacklight::SearchBuilder
  def build(user_params = {})
    params = super
    
    # Override facet limits to match Blacklight configuration
    # instead of allowing Solr to return unlimited results
    blacklight_config.facet_fields.each do |field_name, facet_config|
      limit = facet_config.limit || 5
      params[:"f.#{field_name}.facet.limit"] = limit
    end
    
    params
  end
end
