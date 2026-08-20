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
  Rails.logger.info "=== FacetLimitEnforcer: Starting decorator setup ==="
  
  begin
    if AdvSearchBuilder.include?(FacetLimitEnforcer)
      Rails.logger.info "=== FacetLimitEnforcer: Already applied to AdvSearchBuilder ==="
    else
      AdvSearchBuilder.prepend(FacetLimitEnforcer)
      Rails.logger.info "=== FacetLimitEnforcer: Successfully prepended to AdvSearchBuilder ==="
    end
  rescue NameError => e
    Rails.logger.warn("=== FacetLimitEnforcer: AdvSearchBuilder not found: #{e.message} ===")
  end
  
  begin
    if IiifPrint::CatalogSearchBuilder.include?(FacetLimitEnforcer)
      Rails.logger.info "=== FacetLimitEnforcer: Already applied to IiifPrint::CatalogSearchBuilder ==="
    else
      IiifPrint::CatalogSearchBuilder.prepend(FacetLimitEnforcer)
      Rails.logger.info "=== FacetLimitEnforcer: Successfully prepended to IiifPrint::CatalogSearchBuilder ==="
    end
  rescue NameError, NoMethodError => e
    Rails.logger.warn("=== FacetLimitEnforcer: IiifPrint::CatalogSearchBuilder not found: #{e.message} ===")
  end
end
