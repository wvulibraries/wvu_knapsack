# frozen_string_literal: true

# Patch Sprockets to gracefully handle missing blacklight_advanced_search assets
# The blacklight_advanced_search gem doesn't provide JS/CSS assets in this version
# but hyrax-webapp's application.js and application.css still require them.
# This patches the require directive processor to skip missing requires instead of failing.

module Sprockets
  class DirectiveProcessor
    # Store the original process_require_directive method
    alias_method :original_process_require_directive, :process_require_directive

    def process_require_directive(path)
      # Skip blacklight_advanced_search requires - gem doesn't provide these assets
      return if path == 'blacklight_advanced_search'
      
      # Process all other requires normally
      original_process_require_directive(path)
    end
  end
end
