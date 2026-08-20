# frozen_string_literal: true

# Module to decorate search builders with facet limit enforcement
module FacetLimitEnforcer
  def build(user_params = {})
    params = super
    
    # Enforce Solr facet limits for all searches to match Blacklight configuration
    begin
      blacklight_config.facet_fields.each do |field_name, facet_config|
        limit = facet_config.limit || 5
        params[:"f.#{field_name}.facet.limit"] = limit
      end
    rescue StandardError => e
      Rails.logger.warn("FacetLimitEnforcer error: #{e.message}")
    end
    
    params
  end
end

Rails.application.config.to_prepare do
  # Decorate search builders to enforce facet limits
  begin
    AdvSearchBuilder.prepend(FacetLimitEnforcer) unless AdvSearchBuilder.include?(FacetLimitEnforcer)
  rescue NameError
    # AdvSearchBuilder not yet defined, will try again on next load
  end
  
  begin
    IiifPrint::CatalogSearchBuilder.prepend(FacetLimitEnforcer) unless IiifPrint::CatalogSearchBuilder.include?(FacetLimitEnforcer)
  rescue NameError, NoMethodError
    # IiifPrint not yet defined, will try again on next load
  end
end
