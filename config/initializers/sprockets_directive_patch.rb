# frozen_string_literal: true

# Pre-process Sprockets directives to remove the missing blacklight_advanced_search requires
# This registers a preprocessor that strips out the problematic requires before compilation.

# Register preprocessors for CSS and JS files to remove blacklight_advanced_search requires
if defined?(Sprockets)
  Sprockets.register_preprocessor('text/css', -> (input) {
    data = input[:data]
    # Remove "*= require blacklight_advanced_search" lines
    data.gsub(%r{^\s*\*=\s*require\s+blacklight_advanced_search\s*$}, '')
  })

  Sprockets.register_preprocessor('application/javascript', -> (input) {
    data = input[:data]
    # Remove "//= require blacklight_advanced_search" lines
    data.gsub(%r{^//=\s*require\s+blacklight_advanced_search\s*$}, '')
  })
end
