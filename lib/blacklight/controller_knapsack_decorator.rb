# OVERRIDE: blacklight_range_limit's "view larger" link on every range
# facet builds its URL via #search_facet_path, which always targets
# whatever controller is rendering the current page. That's fine on the
# main search page (CatalogController has a `facet` route), but breaks
# on Advanced Search (AdvancedController has no `facet` route) --
# raising ActionController::UrlGenerationError the moment any range
# facet shows there. Date Created was our first range facet, so we're
# the first to hit it.
#
# hyrax-webapp is a git submodule pinned to upstream Samvera/Hyku -- we
# don't edit files inside it. This decorator is prepended on top
# instead, same pattern as
# lib/blacklight_advanced_search/render_constraints_override_decorator.rb
module Blacklight
  module ControllerKnapsackDecorator
    def search_facet_path(options = {})
      return super unless is_a?(BlacklightAdvancedSearch::AdvancedController)

      opts = search_state
             .to_h
             .merge(action: "facet", controller: "catalog", only_path: true)
             .merge(options)
             .except(:page)

      url_for(opts)
    end
  end
end

# Prepending onto ControllerDecorator (not Controller directly) beats
# hyrax-webapp's own prepend regardless of which engine's loader runs first.
begin
  Blacklight::ControllerDecorator.prepend(Blacklight::ControllerKnapsackDecorator)
rescue NameError
  Blacklight::Controller.prepend(Blacklight::ControllerKnapsackDecorator)
end