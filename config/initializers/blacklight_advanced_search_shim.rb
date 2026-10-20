# frozen_string_literal: true

# SHIM: Define missing BlacklightAdvancedSearch classes
# These are expected by various parts of the application but may not exist in all
# versions of the blacklight_advanced_search gem (particularly 8.x).
# This shim ensures they exist so decorators can check for them without NameError.

# Use to_prepare to ensure CatalogController is loaded before we try to inherit from it
Rails.application.config.to_prepare do
  unless defined?(BlacklightAdvancedSearch::RenderConstraintsOverride)
    module BlacklightAdvancedSearch
      module RenderConstraintsOverride
        # Empty module - the actual behavior is added via decorator in
        # lib/blacklight_advanced_search/render_constraints_override_decorator.rb
      end
    end
  end

  unless defined?(BlacklightAdvancedSearch::AdvancedController)
    module BlacklightAdvancedSearch
      # Stub AdvancedController - actual implementation may come from gem or not be needed
      class AdvancedController < CatalogController
        # Minimal implementation - just inherits from CatalogController
        # Real advanced search logic comes from blacklight_advanced_search gem
      end
    end
  end
end

