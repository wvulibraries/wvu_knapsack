# frozen_string_literal: true

# Knapsack override: enforce facet limits on catalog search
# The catalog uses AdvSearchBuilder which builds Solr params.
# We wrap it to enforce facet.limit values from Blacklight configuration.
class CatalogSearchBuilderWrapper < AdvSearchBuilder
  def build(user_params = {})
    params = super
    
    # After super builds the params, override facet limits
    # to match Blacklight configuration (default 5)
    blacklight_config.facet_fields.each do |field_name, facet_config|
      limit = facet_config.limit || 5
      params[:"f.#{field_name}.facet.limit"] = limit
    end
    
    params
  end
end
