# frozen_string_literal: true

# Knapsack override: enforce facet limit on homepage queries
# HomepageSearchBuilder from Hyku core sends facet.limit => -1 (unlimited) to Solr
# This decorator overrides that behavior to use the Blacklight config limit (5)
module Hyrax
  class HomepageSearchBuilder
    prepend(Module.new do
      private

      def add_facet_params_and_limits(solr_params)
        super
        
        # Override HomepageSearchBuilder's unlimited facet fetches
        # Enforce limit: 5 from Blacklight config for all facets
        blacklight_config.facet_fields.each do |field_name, facet_config|
          limit = facet_config.limit || 5
          solr_params[:"f.#{field_name}.facet.limit"] = limit
        end
      end
    end)
  end
end
