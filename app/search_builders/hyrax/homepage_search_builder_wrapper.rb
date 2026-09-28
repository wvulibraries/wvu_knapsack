# frozen_string_literal: true

module Hyrax
  # Knapsack override: enforce facet limits on homepage
  # The HomepageSearchBuilder builds Solr params. We override it to set
  # proper facet.limit values instead of -1 (unlimited) from parent
  class HomepageSearchBuilderWrapper < Hyrax::HomepageSearchBuilder
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
end
