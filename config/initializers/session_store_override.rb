# frozen_string_literal: true

# Override the session store's secure flag when running without SSL.
# hyrax-webapp's session_store.rb sets secure: true in production, which
# marks the cookie as Secure — browsers refuse to send it over plain HTTP.
# When DISABLE_FORCE_SSL=true (smoke-testing without an SSL proxy) we
# re-configure the session store with secure: false so CSRF works over HTTP.
if ENV['DISABLE_FORCE_SSL'] == 'true' && ENV['REDIS_URL'].present?
  redis_url = ENV['REDIS_URL']
  session_url = "#{redis_url}/session"

  Rails.application.config.session_store :redis_store,
    url: session_url,
    expire_after: 180.days,
    key: '_hyku_session',
    threadsafe: true,
    secure: false,
    same_site: :lax,
    httponly: true
end
