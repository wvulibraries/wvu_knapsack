# frozen_string_literal: true

# Load Hyrax helper override to fix facet drilling (Hyku #3072)
# This override prepends the custom index_field_link implementation
# that adds _sim suffix to bare M3 property names.

Rails.configuration.to_prepare do
  require_relative '../../app/helpers/hyrax/override_helper_behavior'
end
