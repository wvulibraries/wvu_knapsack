# frozen_string_literal: true

# Override Valkyrie's resource_class_resolver to handle cases where
# Wings::ModelRegistry is not available at runtime.
# This patches the resolver set by hyrax-webapp's wings.rb initializer
# without modifying the submodule.

Valkyrie.config.resource_class_resolver = lambda do |resource_klass_name|
  klass = resource_klass_name.gsub(/Resource$/, '').constantize
  
  # Only attempt reverse_lookup if Wings::ModelRegistry is available
  if defined?(Wings::ModelRegistry) && Wings::ModelRegistry.respond_to?(:reverse_lookup)
    begin
      Wings::ModelRegistry.reverse_lookup(klass) || klass
    rescue NameError, NoMethodError
      # If reverse_lookup fails for any reason, fall back to the class itself
      klass
    end
  else
    # Wings not loaded or ModelRegistry not available - just return the class
    klass
  end
end
