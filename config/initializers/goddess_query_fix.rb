# Defensive patch for Goddess::Query::MethodMissingMachinations#model_class_for
# Prevents NameError when Wings::ModelRegistry is not available
# Issue: lib/goddess/query.rb:17 tries to access undefined constant
# The method is in the Goddess module included in CustomQueryContainer

Rails.application.config.to_prepare do
  if defined?(Goddess::Query::MethodMissingMachinations)
    # Create a module to prepend that overrides model_class_for
    # Prepending ensures this version is called first (before the original)
    goddess_patch = Module.new do
      def model_class_for(model)
        internal_resource = model.respond_to?(:internal_resource) ? model.internal_resource : nil
        
        # Try to constantize internal_resource first
        if internal_resource&.safe_constantize
          return internal_resource.safe_constantize
        end
        
        # Defensively check if Wings::ModelRegistry is available before using it
        if defined?(Wings::ModelRegistry)
          Wings::ModelRegistry.lookup(model)
        else
          # Fall back to the model class itself if Wings isn't loaded
          model.is_a?(Class) ? model : model.class
        end
      end
    end
    
    # Prepend ensures this patched version is invoked before the original
    Goddess::Query::MethodMissingMachinations.prepend(goddess_patch)
  end
end
