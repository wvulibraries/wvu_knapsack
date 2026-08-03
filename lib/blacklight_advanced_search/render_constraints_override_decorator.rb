# frozen_string_literal: true

# OVERRIDE Blacklight Advanced Search v7.0.0 to prevent double rendering of constraint filters

module BlacklightAdvancedSearch
  module RenderConstraintsOverrideDecorator
    def render_constraints_filters(params_or_search_state = search_state)
      super(params_or_search_state)
    end
  end
end

if defined?(BlacklightAdvancedSearch::RenderConstraintsOverride)
  # blacklight_advanced_search <= 7 (old hook point)
  BlacklightAdvancedSearch::RenderConstraintsOverride.prepend(
    BlacklightAdvancedSearch::RenderConstraintsOverrideDecorator
  )
elsif defined?(Blacklight::RenderConstraintsHelperBehavior)
  # blacklight_advanced_search 8+ (RenderConstraintsOverride removed/renamed)
  Blacklight::RenderConstraintsHelperBehavior.prepend(
    BlacklightAdvancedSearch::RenderConstraintsOverrideDecorator
  )
end
