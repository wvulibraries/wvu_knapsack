module CatalogControllerDecorator
  CatalogController.configure_blacklight do |config|
    config.advanced_search[:form_facet_partial] = "advanced_search_facets"

    config.per_page = [6, 12, 24, 48, 96]
    config.default_per_page = 12

    # Hyku #3072: Hide Type facet — remove BEFORE base config registers it
    # to avoid race condition with to_prepare load order.
    # Must be done inside configure_blacklight (not to_prepare) so it
    # executes during config evaluation, not boot time.
    config.add_facet_field 'generic_type_sim', show: false

    # date_created_years_ssim holds every year a record's date_created
    # covers, populated by date_created_years_indexer_decorator.rb. One
    # range facet, one field, covers Works and Collections uniformly.
    unless config.facet_fields.key?('date_created_years_ssim')
      config.add_facet_field 'date_created_years_ssim', label: 'Date Created', range: {
        segments: false,
        slider_js: false
      }
    end

    # date_created_sim is no longer used with M3 flexible metadata.
    # Register it as hidden first so Hyrax's auto-add logic skips it.
    unless config.facet_fields.key?('date_created_sim')
      config.add_facet_field 'date_created_sim', show: false
    end
  end

  # Suppress date_created_sim on every request (belt-and-suspenders against
  # to_prepare race conditions where initializer runs after this decorator).
  CatalogController.before_action(prepend: true) do
    blacklight_config.facet_fields.delete('date_created_sim') if blacklight_config&.facet_fields&.key?('date_created_sim')
  end
end