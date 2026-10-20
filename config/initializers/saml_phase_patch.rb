# frozen_string_literal: true

# SAML Authentication Phase Patch for Hyku 7.2
#
# Hyku 7.2 upgraded omniauth-saml gem which changed the behavior of
# OmniAuth::Strategies::SAML#current_phase to return a Boolean instead of Integer.
# However, the omni_auth/strategies/saml_decorator.rb code still tries to perform
# arithmetic on the result (current_phase + 1), causing:
#   NoMethodError (undefined method '+' for true:TrueClass)
#
# This patch ensures current_phase always returns an Integer for backward compatibility.
#
# Reference: lib/omni_auth/strategies/saml_decorator.rb:32

Rails.application.config.to_prepare do
  next unless defined?(OmniAuth::Strategies::SAML)

  # Monkey-patch the current_phase method to return an integer
  OmniAuth::Strategies::SAML.class_eval do
    def current_phase
      # Force the result to be an integer
      # If the base implementation returns true/false, convert to 1/0
      # If it returns an integer, use it as-is
      phase = super
      phase.is_a?(Integer) ? phase : (phase ? 1 : 0)
    end
  end
end
