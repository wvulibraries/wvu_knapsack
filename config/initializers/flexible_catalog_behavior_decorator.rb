# frozen_string_literal: true

# Override the default facet limit for flexible/M3 metadata fields in Hyrax 7.2.
# Hyrax::FlexibleCatalogBehavior.load_flexible_schema (a class method) calls
# blacklight_config.add_facet_field(name, label:) with NO limit parameter →
# Blacklight defaults to 10. Since load_flexible_schema may have already been
# called during Rails boot (before this initializer runs), we fix the limits
# directly on the already-instantiated facet_fields.

if defined?(Hyrax::FlexibleCatalogBehavior) && Hyrax.config.flexible?
  begin
    # Iterate through facet_fields and set limit: 5 for any with no explicit limit.
    # This catches flexible facets that were registered with no limit (defaults to 10
    # in Blacklight), while preserving static catalog_controller facets (already 5).
    CatalogController.blacklight_config.facet_fields.each_value do |field_config|
      # Convert nil or missing limit to 5 for flexible facets
      # Static facets from catalog_controller already have explicit limit: 5
      field_config.limit = 5 if field_config.limit.nil?
    end
    Rails.logger.info "[knapsack] Fixed flexible facet limits to 5"
  rescue => e
    Rails.logger.warn "[knapsack] Error fixing flexible facet limits: #{e.message}"
  end
end
