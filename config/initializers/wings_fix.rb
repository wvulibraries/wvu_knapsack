# frozen_string_literal: true

# Patch for hyrax-webapp's wings.rb initializer
# Adds defensive check for Wings::ModelRegistry constant to prevent
# NameError when the constant is not yet available during initialization
#
# This fixes: "uninitialized constant Wings::ModelRegistry" errors
# See: hyrax-webapp/config/initializers/wings.rb line ~200

Rails.application.config.to_prepare do
  # Only apply patch if Wings::ModelRegistry is not already defined in the lambda
  # and if we're in the non-disable_wings path
  if !Hyrax.config.disable_wings && defined?(Valkyrie)
    # Re-register the resource_class_resolver with the defensive check
    Valkyrie.config.resource_class_resolver = lambda do |resource_klass_name|
      klass = resource_klass_name.gsub(/Resource$/, '').constantize
      if defined?(Wings::ModelRegistry)
        Wings::ModelRegistry.reverse_lookup(klass) || klass
      else
        klass
      end
    end
  end
end
