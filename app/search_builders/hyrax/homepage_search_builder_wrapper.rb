# frozen_string_literal: true

module Hyrax
  # Knapsack override: enforce facet limits on homepage
  # Wraps the parent search builder to respect Blacklight facet config limits
  class HomepageSearchBuilderWrapper < Hyrax::HomepageSearchBuilder
    def initialize(context)
      super
      @facet_limit_processed = false
    end

    protected

    def append_facets(solr_params)
      super
      
      # After parent class adds facets, override the limits to match Blacklight config
      unless @facet_limit_processed
        blacklight_config.facet_fields.each do |field_name, facet_config|
          limit = facet_config.limit || 5
          solr_params[:"f.#{field_name}.facet.limit"] = limit
        end
        @facet_limit_processed = true
      end
    end
  end
end
