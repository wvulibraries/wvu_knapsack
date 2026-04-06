# frozen_string_literal: true

# Includes AiMetadataBehavior into FileSet so the after_create_commit hook
# fires during Bulkrax import and enqueues the correct AI remediation job.
#
# Uses config.to_prepare rather than after_initialize so the include survives
# Zeitwerk class reloading in development mode.
#
# FileSet and AiMetadataBehavior are both autoloaded — the guard keeps this
# safe if either constant is not yet defined at boot (e.g. in test stubs).
Rails.application.config.to_prepare do
  if defined?(FileSet) && defined?(AiMetadataBehavior)
    FileSet.include AiMetadataBehavior unless FileSet.ancestors.include?(AiMetadataBehavior)
  end
end
