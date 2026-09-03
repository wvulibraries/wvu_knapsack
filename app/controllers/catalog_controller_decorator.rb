# frozen_string_literal: true

module CatalogControllerDecorator
  # Configuration for CatalogController's Blacklight setup
  # This code runs when the decorator is loaded (in to_prepare)
  CatalogController.configure_blacklight do |config|
    config.advanced_search[:form_facet_partial] = "advanced_search_facets"

    # adjust pagination
    config.per_page = [6, 12, 24, 48, 96]
    config.default_per_page = 12

    # date_created_years_ssim holds every year a record's date_created
    # covers, populated by date_created_years_indexer_decorator.rb. One
    # range facet, one field, covers Works and Collections uniformly.
    unless config.facet_fields.key?('date_created_years_ssim')
      config.add_facet_field 'date_created_years_ssim', label: 'Date Created', range: {
        segments: false,
        slider_js: false
      }
    end

    # Suppress the old plain-value-list facet so we don't get two "Date
    # Created" facets. Registering it here first makes Hyrax's own
    # auto-add logic (which only adds it if nothing has claimed the
    # field yet) skip re-adding a visible version.
    unless config.facet_fields.key?('date_created_sim')
      config.add_facet_field 'date_created_sim', show: false
    end
  end
end
