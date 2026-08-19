# frozen_string_literal: true

# Wrap Valkyrie's resource_class_resolver to guard against Wings::ModelRegistry NameError
# The hyrax-webapp initializer sets this up, but Wings may not be available at certain times
# This guard ensures the resolver is safe to call even if Wings isn't initialized yet

after_init_proc = lambda do
  # Store the original resolver if it was set
  original_resolver = Valkyrie.config.resource_class_resolver
  
  # Replace with a guarded version
  Valkyrie.config.resource_class_resolver = lambda do |resource_klass_name|
    begin
      # Try to use the original resolver if it exists
      if original_resolver.respond_to?(:call)
        original_resolver.call(resource_klass_name)
      else
        # Fallback: handle directly if original not available
        klass = resource_klass_name.gsub(/Resource$/, '').constantize
        if defined?(Wings::ModelRegistry)
          Wings::ModelRegistry.reverse_lookup(klass) || klass
        else
          klass
        end
      end
    rescue NameError => e
      # If Wings::ModelRegistry isn't available, just constantize
      begin
        resource_klass_name.gsub(/Resource$/, '').constantize
      rescue NameError
        # Last resort: return the string as-is
        Rails.logger.warn("Valkyrie resolver could not resolve #{resource_klass_name}: #{e.message}")
        resource_klass_name
      end
    rescue StandardError => e
      Rails.logger.warn("Valkyrie resolver error for #{resource_klass_name}: #{e.message}")
      resource_klass_name
    end
  end
end

# Run after initialization completes
Rails.application.config.after_initialize(&after_init_proc)
