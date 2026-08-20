# frozen_string_literal: true

# Module to decorate search builders with facet limit enforcement
module FacetLimitEnforcer
  def build(user_params = {})
    Rails.logger.info "[FacetLimitEnforcer] build() called on #{self.class.name} with user_params: #{user_params.keys.inspect}"
    params = super
    Rails.logger.info "[FacetLimitEnforcer] after super, params keys: #{params.keys.first(10).inspect}"
    
    # Enforce Solr facet limits for all searches to match Blacklight configuration
    begin
      blacklight_config.facet_fields.each do |field_name, facet_config|
        limit = facet_config.limit || 5
        params[:"f.#{field_name}.facet.limit"] = limit
      end
      Rails.logger.info "[FacetLimitEnforcer] set facet limits, new params keys: #{params.keys.grep(/facet.limit/).inspect}"
    rescue StandardError => e
      Rails.logger.warn("[FacetLimitEnforcer] error: #{e.class} #{e.message}")
    end
    
    params
  end
end

# Apply the decorator during initialization
Rails.application.config.after_initialize do
  Rails.logger.info "[FacetLimitEnforcer] after_initialize: decorating search builders"
  
  begin
    # Don't check if already included - just prepend
    AdvSearchBuilder.prepend(FacetLimitEnforcer) 
    Rails.logger.info "[FacetLimitEnforcer] prepended to AdvSearchBuilder"
  rescue StandardError => e
    Rails.logger.warn("[FacetLimitEnforcer] failed to prepend to AdvSearchBuilder: #{e.class} #{e.message}")
  end
  
  begin
    # Don't check if already included - just prepend
    IiifPrint::CatalogSearchBuilder.prepend(FacetLimitEnforcer)
    Rails.logger.info "[FacetLimitEnforcer] prepended to IiifPrint::CatalogSearchBuilder"
  rescue StandardError => e
    Rails.logger.warn("[FacetLimitEnforcer] failed to prepend to IiifPrint::CatalogSearchBuilder: #{e.class} #{e.message}")
  end
end
