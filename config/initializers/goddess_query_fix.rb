# Defensive patch for Hyrax::Goddess::Query#model_class_for
# Prevents NameError when Wings::ModelRegistry is not available
# Issue: lib/goddess/query.rb:17 tries to access undefined constant

Rails.application.config.to_prepare do
  if defined?(Hyrax::Goddess::Query)
    Hyrax::Goddess::Query.class_eval do
      def model_class_for(model)
        internal_resource = model.respond_to?(:internal_resource) ? model.internal_resource : nil
        
        # Try to constantize internal_resource first
        return internal_resource.safe_constantize if internal_resource&.safe_constantize
        
        # Defensively check if Wings::ModelRegistry is available before using it
        if defined?(Wings::ModelRegistry)
          Wings::ModelRegistry.lookup(model)
        else
          # Fall back to the model class itself if Wings isn't loaded
          model.is_a?(Class) ? model : model.class
        end
      end
    end
  end
end
