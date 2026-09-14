# frozen_string_literal: true

# Patch the search builder to force Solr facet.limit parameters.
# This ensures Solr honors the facet limits even for facets registered
# by M3 flexible-metadata after initial configuration.

Rails.configuration.to_prepare do
  # Find the search builder class used by CatalogController
  search_builder_class = if defined?(Hyrax::CatalogSearchBuilder)
                           Hyrax::CatalogSearchBuilder
                         elsif defined?(CatalogSearchBuilder)
                           CatalogSearchBuilder
                         else
                           nil
                         end

  next unless search_builder_class

  # Override the build method to inject facet.limit parameters
  search_builder_class.class_eval do
    # Store the original build method if not already patched
    unless method_defined?(:build_without_facet_limits)
      alias_method :build_without_facet_limits, :build

      def build(user_params = {})
        params = build_without_facet_limits(user_params)

        # Ensure ALL facets (including M3-registered ones) get Solr facet.limit
        if defined?(CatalogController) && CatalogController.respond_to?(:blacklight_config)
          blacklight_config = CatalogController.blacklight_config
          if blacklight_config.respond_to?(:facet_fields)
            blacklight_config.facet_fields.each do |field_name, facet_config|
              next if field_name.to_s == 'generic_type_sim'

              # Get the limit from config, default to 5
              limit = facet_config.limit || 5

              # CRITICAL: Set to limit+1 so Blacklight can detect "more" link
              # Solr must return 1 extra item to trigger "more" link in UI
              params[:"f.#{field_name}.facet.limit"] = (limit + 1).to_i
            end
          end
        end

        params
      end
    end
  end
rescue NameError, LoadError
  # Skip if search builder not yet defined
end
