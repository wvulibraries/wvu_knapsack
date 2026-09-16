# frozen_string_literal: true

# Knapsack override: enforce facet limits on catalog search
# The catalog uses AdvSearchBuilder which builds Solr params.
# We wrap it to enforce facet.limit values from Blacklight configuration.
# 
# NOTE: This is NOT currently used. The active search builder is CatalogSearchBuilder
# (set in config/initializers/catalog_controller_decorator.rb).
# This file kept for reference and as a fallback pattern.
class CatalogSearchBuilderWrapper < AdvSearchBuilder
  def build(user_params = {})
    params = super
    
    # After super builds the params, override facet limits
    # CRITICAL: Set facet.limit to (limit + 1) so Blacklight can detect "more" items
    # Example: If limit=5, request 6 from Solr. If Solr returns 6, show "more" link.
    blacklight_config.facet_fields.each do |field_name, facet_config|
      limit = facet_config.limit || 5
      facet_limit_value = (limit + 1).to_i
      params[:"f.#{field_name}.facet.limit"] = facet_limit_value
    end
    
    params
  end
end
