# frozen_string_literal: true

# Patch Sprockets DirectiveProcessor to gracefully handle missing blacklight_advanced_search
# This gem doesn't provide assets in this version, but hyrax-webapp still requires it.
# Instead of raising FileNotFound, we'll silently skip these requires.

Sprockets::DirectiveProcessor.class_eval do
  alias_method :original_process_require_directive, :process_require_directive

  def process_require_directive(path)
    # Skip the blacklight_advanced_search require - it doesn't provide assets
    return if path == 'blacklight_advanced_search'

    original_process_require_directive(path)
  end
end
