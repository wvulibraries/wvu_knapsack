module CatalogControllerDecorator
  CatalogController.configure_blacklight do |config|
    config.advanced_search[:form_facet_partial] = "advanced_search_facets"

    config.per_page = [6, 12, 24, 48, 96]
    config.default_per_page = 12

    unless config.facet_fields.key?('date_created_years_ssim')
      config.add_facet_field 'date_created_years_ssim', label: 'Date Created', range: {
        segments: false,
        slider_js: false
      }
    end
  end

  # The M3 facet-limiting initializer (config/initializers/catalog_controller_decorator.rb)
  # auto-registers date_created_sim as a visible facet regardless of load order. Force it
  # closed on every request rather than racing that initializer at boot time.
  CatalogController.before_action(prepend: true) do
    blacklight_config.facet_fields.delete('date_created_sim')
  end
end