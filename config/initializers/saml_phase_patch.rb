# frozen_string_literal: true

# TEMPORARY WORKAROUND: SAML Authentication Phase Patch for Hyku 7.2
#
# UPSTREAM ISSUE: Hyku 7.2 with omniauth-saml ~> 2.1 has a regression where
# OmniAuth::Strategies::SAML#current_phase returns Boolean instead of Integer.
# The omniauth decorator code (lib/omni_auth/strategies/saml_decorator.rb:32)
# expects an integer and tries arithmetic (current_phase + 1), causing:
#   NoMethodError (undefined method '+' for true:TrueClass)
#
# ERROR LOCATION: lib/omni_auth/strategies/saml_decorator.rb:32 in `other_phase`
# AFFECTED VERSIONS: Hyku 7.2.0 with omniauth-saml ~> 2.1
#
# RECOMMENDED RESOLUTION:
# 1. Check Samvera/Hyku issues for reported bugs (search "current_phase")
# 2. Update omniauth-saml to a version that fixes this (> 2.1.3 if available)
# 3. Or patch omniauth-saml upstream if not yet fixed
# 4. Remove this initializer once upstream issue is resolved
#
# TODO: Remove this patch when Hyku or omniauth-saml releases a fix
# See: https://github.com/samvera/hyku/issues (search for SAML current_phase)

Rails.application.config.to_prepare do
  next unless defined?(OmniAuth::Strategies::SAML)

  # Monkey-patch the current_phase method to return an integer
  # This ensures backward compatibility until upstream fixes the regression
  OmniAuth::Strategies::SAML.class_eval do
    def current_phase
      phase = super
      # If the base implementation returns true/false, convert to 1/0
      # If it returns an integer, use it as-is
      phase.is_a?(Integer) ? phase : (phase ? 1 : 0)
    end
  end
end
