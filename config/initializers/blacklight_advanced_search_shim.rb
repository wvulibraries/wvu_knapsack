# frozen_string_literal: true

# SHIM: Define BlacklightAdvancedSearch::RenderConstraintsOverride if missing
# This module is expected by SearchHistoryController in hyrax-webapp but may not exist
# in all versions of blacklight_advanced_search (particularly 8+).
# This shim ensures the module exists so the controller can include it without errors.

unless defined?(BlacklightAdvancedSearch::RenderConstraintsOverride)
  module BlacklightAdvancedSearch
    module RenderConstraintsOverride
      # Empty module - the actual behavior is added via decorator in
      # lib/blacklight_advanced_search/render_constraints_override_decorator.rb
    end
  end
end
