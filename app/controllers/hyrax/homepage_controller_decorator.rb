# frozen_string_literal: true

# Knapsack override: use custom HomepageSearchBuilder that respects facet limits
module Hyrax
  module HomepageControllerDecorator
    def search_builder_class
      Hyrax::HomepageSearchBuilderWrapper
    end
  end
end

Hyrax::HomepageController.prepend(Hyrax::HomepageControllerDecorator)
