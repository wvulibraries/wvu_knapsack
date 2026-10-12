# frozen_string_literal: true

# TEMPORARY: Override Hyku VERSION constant to 7.2.0
# This override is needed because upstream hyku's 7.2-stable branch hasn't
# bumped the VERSION constant yet (see samvera/hyku#3397).
#
# Once the version fix PR is merged to 7.2-stable and we update the submodule
# reference, this file should be DELETED immediately as it will no longer be needed.
#
# DO NOT commit this as a permanent solution - it exists only to enable testing
# during the 7.2.0 upgrade validation phase.

module Hyku
  # Store original version for reference
  ORIGINAL_VERSION = VERSION
  
  # Override to 7.2.0
  remove_const(:VERSION) if const_defined?(:VERSION)
  VERSION = '7.2.0'
end

Rails.logger.info "[WVU Knapsack] Temporarily overriding Hyku VERSION from '#{Hyku::ORIGINAL_VERSION}' to '#{Hyku::VERSION}' (will be removed when samvera/hyku#3397 is resolved)"
