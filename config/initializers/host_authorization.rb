# frozen_string_literal: true

# Allow requests from all WVU library production subdomains.
# A leading-dot string is matched against request.host (no port) as a suffix,
# so "*.lib.wvu.edu" hostnames (e.g. hyku.lib.wvu.edu) are permitted.
Rails.application.config.hosts << ".lib.wvu.edu"

# Allow additional hosts via comma-separated HYKU_EXTRA_HOSTS env var.
# Use this in a gitignored local .env.production for smoke-testing without
# touching production config. Example for lvh.me (wildcard → 127.0.0.1):
#   HYKU_EXTRA_HOSTS=.lvh.me
if ENV['HYKU_EXTRA_HOSTS'].present?
  ENV['HYKU_EXTRA_HOSTS'].split(',').map(&:strip).each do |host|
    Rails.application.config.hosts << host
  end
end

# hyrax-webapp's production.rb hard-codes config.force_ssl = true.
# On the VM an SSL-terminating reverse proxy sits in front of the app and
# forwards plain HTTP, so force_ssl must remain on.
# If you ever need to run the production Rails env without an SSL proxy
# (e.g. smoke-testing a build), set DISABLE_FORCE_SSL=true in .env.production.
Rails.application.config.middleware.delete(ActionDispatch::SSL) if ENV['DISABLE_FORCE_SSL'] == 'true'
