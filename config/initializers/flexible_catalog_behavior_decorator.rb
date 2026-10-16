# frozen_string_literal: true

# Override the default facet limit for flexible/M3 metadata fields in Hyrax 7.2.
# Hyrax::FlexibleCatalogBehavior.load_flexible_schema (a class method) calls
# blacklight_config.add_facet_field(name, label:) with NO limit parameter →
# Blacklight defaults to 10. This initializer prepends on the class method and
# fixes flexible facets to limit: 5 (matching static catalog_controller facets),
# ensuring Solr receives limit+1 so Blacklight can show a "More" link.

module Hyrax
  module FlexibleCatalogBehaviorDecorator
    def load_flexible_schema(*)
      super
      # After Hyrax registers all flexible facets (with no limit → default 10),
      # iterate through facet_fields and set limit to 5 for fields added by this method.
      # Static fields in catalog_controller already have limit: 5 and won't change.
      CatalogController.blacklight_config.facet_fields.each_value do |field_config|
        # Only override fields that got Blacklight's default (10); preserve explicit limits
        field_config.limit = 5 if field_config.limit == 10
      end
    rescue => e
      Rails.logger.warn "[knapsack] FlexibleCatalogBehaviorDecorator: #{e.message}"
    end
  end
end

if defined?(Hyrax::FlexibleCatalogBehavior) && Hyrax.config.flexible?
  # load_flexible_schema is a class method inside class_methods do; prepend on
  # the singleton_class to override the class method (not instance method).
  Hyrax::FlexibleCatalogBehavior.singleton_class.prepend(
    Hyrax::FlexibleCatalogBehaviorDecorator
  )
end
