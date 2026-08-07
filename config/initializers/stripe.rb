# frozen_string_literal: true

# Point the Stripe client at our secret key when one is configured. Wrapped in
# to_prepare so the autoloaded StripeConfig is available (initializers run
# before autoloading is ready). Guarded so boot doesn't fail in environments
# (dev without keys, CI) where Stripe isn't set up — those paths are either
# unused or stubbed in tests.
Rails.application.config.to_prepare do
	Stripe.api_key = StripeConfig.secret_key if StripeConfig.configured?
end
