# frozen_string_literal: true

# OVERRIDE Hyrax v5.2.0 Hyrax::OverrideHelperBehavior
# Upstream writes the bare M3 property name (e.g. "contributor") into
# the catalog URL as search_field=contributor, which targets no real
# Solr field. Prefer the facet form when the index field config has a
# link_to_facet set; otherwise suffix _sim onto the bare name so the
# search_field= URL routes to the indexed _sim field.
#
# This fix allows users to click metadata values on search result rows
# and successfully drill down into related works (Hyku #3072).

module Hyrax
  module OverrideHelperBehavior
    # OVERRIDE Hyrax v5.2.0 Hyrax::HyraxHelperBehavior#index_field_link
    def index_field_link(options)
      raise ArgumentError unless options[:config] && options[:config][:field_name]
      
      facet_field = options[:config].try(:link_to_facet) || options[:config][:link_to_facet]
      
      if facet_field.present?
        # Prefer facet form when link_to_facet is explicitly configured
        safe_join(options[:value].map { |item| link_to_facet(item, facet_field) }, ", ")
      else
        # Fall back to direct field link with _sim suffix added if not already present
        name = options[:config][:field_name].to_s
        name = "#{name}_sim" unless name.match?(/_(sim|ssim|tesim|tsim|ssi|tsi|dtsi)\z/)
        safe_join(options[:value].map { |item| link_to_field(name, item, item) }, ", ")
      end
    end
  end
end

Hyrax::HyraxHelperBehavior.prepend(Hyrax::OverrideHelperBehavior)
