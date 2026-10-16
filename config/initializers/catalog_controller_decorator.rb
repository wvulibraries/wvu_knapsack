# frozen_string_literal: true

# Configure CatalogController to use our custom search builder
# This must run AFTER hyrax-webapp's catalog controller initializes
Rails.application.config.to_prepare do
  next unless defined?(::CatalogController)

  # Override the Blacklight configuration to use our custom search builder
  ::CatalogController.configure_blacklight do |config|
    # Set custom search builder that injects facet limit parameters
    config.search_builder_class = ::CatalogSearchBuilder

    # Advanced search facet partial
    config.advanced_search[:form_facet_partial] = "advanced_search_facets"

    # Pagination settings
    config.per_page = [6, 12, 24, 48, 96]
    config.default_per_page = 12

    # Hyku #3072: Hide Type facet (not needed for WVU theme)
    config.facet_fields.delete('generic_type_sim')

    # Dynamically register M3 flexible-metadata facets from the ACTIVE metadata profile
    # Uses Hyrax::FlexibleSchema to get what's currently active (not static file in repo)
    # ONLY registers fields explicitly marked as facetable in the M3 profile
    
    m3_facets = {}
    
    # Try to load from active FlexibleSchema context (tenant's M3 profile)
    begin
      if Hyrax.config.flexible?
        # Get the CURRENT tenant's active schema - this is the active M3 profile
        # Use current_version if available (tenant-aware), fallback to last created
        schema = if defined?(Hyrax::FlexibleSchema) && Hyrax::FlexibleSchema.respond_to?(:current_version)
                   Hyrax::FlexibleSchema.current_version
                 else
                   Hyrax::FlexibleSchema.order("created_at asc").last
                 end
        
        # Handle both Hash and ActiveRecord model responses
        profile_data = if schema.is_a?(Hash)
                         # schema is already a Hash
                         schema
                       elsif schema.respond_to?(:profile)
                         # schema is an ActiveRecord model with .profile method
                         schema.profile
                       else
                         nil
                       end
        
        if profile_data.is_a?(Hash)
          properties = profile_data.dig('properties') || {}
          
          # Iterate all properties and register those with _sim fields
          # NOTE: Do NOT filter by 'facetable' marker — many real facets lack that token
          properties.each do |property_name, property_def|
            next unless property_def.is_a?(Hash)
            
            # Get indexing array (contains field names like creator_sim, creator_tesim, etc.)
            indexing = property_def['indexing']
            next unless indexing.is_a?(Array)
            
            # Find ALL _sim fields in this property's indexing
            indexing.each do |field|
              next unless field.to_s.end_with?('_sim')
              
              # Skip if already configured in base Hyku config
              next if config.facet_fields.key?(field)
              
              # Extract human-readable label, avoiding i18n keys
              label = property_def.dig('display_label', 'en') || 
                      property_def.dig('display_label', 'default')
              
              # If label is an i18n key (starts with blacklight.), use human-readable property name
              if label.nil? || label.to_s.start_with?('blacklight.')
                label = property_name.gsub('_', ' ').titleize
              end
              
              m3_facets[field] = label
              Rails.logger.debug("Found M3 facet: #{field} => #{label}")
            end
          end
          
          if m3_facets.any?
            Rails.logger.info("Registered #{m3_facets.size} M3 facets from active FlexibleSchema")
          else
            Rails.logger.warn("No _sim properties found in active FlexibleSchema")
          end
        else
          Rails.logger.warn("Could not extract profile data from FlexibleSchema (got #{schema.class})")
        end
      else
        Rails.logger.warn("Flexible metadata not enabled (Hyrax.config.flexible? = false)")
      end
    rescue StandardError => e
      Rails.logger.warn("Error loading facets from FlexibleSchema: #{e.message} (#{e.class})")
      Rails.logger.debug(e.backtrace.join("\n"))
    end
    
    # Register all discovered M3 facets with Blacklight
    m3_facets.each do |field_name, label|
      # Skip if already configured (e.g., from hyrax-webapp base config)
      next if config.facet_fields.key?(field_name)
      
      config.add_facet_field field_name, label: label, limit: 5, show_more: true
      Rails.logger.debug("Registered M3 facet: #{field_name} => #{label}")
    end
    
    Rails.logger.info("Total M3 facets registered: #{m3_facets.size}")
    
    # YAML-driven configuration for critical WVU facets and defaults
    yaml_path = Rails.root.join('config', 'wvu_facet_defaults.yml')
    yml_config = File.exist?(yaml_path) ? YAML.load_file(yaml_path) : {}
    
    force_fields = yml_config.fetch('force_registered_fields', {})
    defaults = yml_config.fetch('defaults', { limit: 5, show_more: true })

    # 1. Handle critical fields defined in YAML
    force_fields.each do |field_name, label|
      if config.facet_fields.key?(field_name)
        config.facet_fields[field_name].limit = defaults['limit']
        config.facet_fields[field_name].label = label
        Rails.logger.info("Updated existing facet: #{field_name} => #{label} (limit: #{defaults['limit']})")
      else
        config.add_facet_field field_name, 
                               label: label, 
                               limit: defaults['limit'], 
                               show_more: defaults['show_more']
        Rails.logger.info("Force-registered missing facet: #{field_name} => #{label} (limit: #{defaults['limit']})")
      end
    end

    # 2. Apply universal default limit to all dynamic _sim fields discovered via FlexibleSchema
    config.facet_fields.each do |key, field_config|
      next unless key.to_s.end_with?('_sim') && field_config.respond_to?(:limit=)
      # Only apply if the field has no explicit limit set yet
      if field_config.limit.nil? || field_config.limit.zero?
        config.facet_fields[key].limit = defaults['limit']
        Rails.logger.debug("Applied default limit #{defaults['limit']} to dynamic facet: #{key}")
      end
    end

  end # configure_blacklight
end # to_prepare

