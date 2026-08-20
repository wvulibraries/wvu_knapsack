# frozen_string_literal: true

# Module to decorate search builders with facet limit enforcement
module FacetLimitEnforcer
  def build(user_params = {})
    Rails.logger.info "FacetLimitEnforcer.build called on #{self.class.name}"
    params = super
    
    # Enforce Solr facet limits for all searches to match Blacklight configuration
    begin
      Rails.logger.info "FacetLimitEnforcer: Processing facet fields"
      blacklight_config.facet_fields.each do |field_name, facet_config|
        limit = facet_config.limit || 5
        Rails.logger.info "FacetLimitEnforcer: Setting f.#{field_name}.facet.limit = #{limit}"
        params[:"f.#{field_name}.facet.limit"] = limit
      end
    rescue StandardError => e
      Rails.logger.warn("FacetLimitEnforcer error: #{e.message}")
    end
    
    Rails.logger.info "FacetLimitEnforcer: Final params = #{params.inspect}"
    params
  end
end

Rails.application.config.to_prepare do
  # Decorate search builders to enforce facet limits
  Rails.logger.info "=== FacetLimitEnforcer: Starting decorator setup ==="
  
  # Check AdvSearchBuilder
  begin
    Rails.logger.info "=== AdvSearchBuilder methods before prepend: #{AdvSearchBuilder.instance_methods(false).first(5).inspect} ==="
    
    if AdvSearchBuilder.include?(FacetLimitEnforcer)
      Rails.logger.info "=== FacetLimitEnforcer: Already applied to AdvSearchBuilder ==="
    else
      AdvSearchBuilder.prepend(FacetLimitEnforcer)
      Rails.logger.info "=== FacetLimitEnforcer: Successfully prepended to AdvSearchBuilder ==="
      Rails.logger.info "=== AdvSearchBuilder methods after prepend: #{AdvSearchBuilder.instance_methods(false).first(5).inspect} ==="
    end
  rescue NameError => e
    Rails.logger.warn("=== FacetLimitEnforcer: AdvSearchBuilder not found: #{e.message} ===")
  end
  
  # Check IiifPrint::CatalogSearchBuilder
  begin
    Rails.logger.info "=== IiifPrint::CatalogSearchBuilder methods before prepend: #{IiifPrint::CatalogSearchBuilder.instance_methods(false).first(5).inspect} ==="
    
    if IiifPrint::CatalogSearchBuilder.include?(FacetLimitEnforcer)
      Rails.logger.info "=== FacetLimitEnforcer: Already applied to IiifPrint::CatalogSearchBuilder ==="
    else
      IiifPrint::CatalogSearchBuilder.prepend(FacetLimitEnforcer)
      Rails.logger.info "=== FacetLimitEnforcer: Successfully prepended to IiifPrint::CatalogSearchBuilder ==="
      Rails.logger.info "=== IiifPrint::CatalogSearchBuilder methods after prepend: #{IiifPrint::CatalogSearchBuilder.instance_methods(false).first(5).inspect} ==="
    end
  rescue NameError, NoMethodError => e
    Rails.logger.warn("=== FacetLimitEnforcer: IiifPrint::CatalogSearchBuilder not found: #{e.message} ===")
  end
end
