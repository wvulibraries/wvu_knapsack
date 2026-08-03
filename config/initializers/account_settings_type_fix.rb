# Fix for Account.settings to handle TEXT column with JSON content
# The settings column is now TEXT (not JSONB) but contains JSON.
# PostgreSQL may return the value already parsed, so we need to handle that.

module JSONCoderWithHashFallback
  def load(value)
    return {} if value.nil? || value == ''
    # If the value is already a Hash (from JSONB conversion), serialize it to JSON first
    if value.is_a?(Hash)
      value = value.to_json
    end
    super(value)
  end
end

# Apply patch in to_prepare hook which runs early and on every reload
Rails.configuration.to_prepare do
  unless ActiveRecord::Coders::JSON.ancestors.include?(JSONCoderWithHashFallback)
    ActiveRecord::Coders::JSON.prepend(JSONCoderWithHashFallback)
  end
end
