# frozen_string_literal: true

# Stripe credentials, resolved from encrypted Rails credentials with an ENV
# fallback — the same dual-layer pattern used by GmailOauth. In test/CI these
# stay nil and every Stripe call is stubbed, so nothing here needs to be set to
# run the suite.
module StripeConfig
	module_function

	def secret_key
		Rails.application.credentials.dig(:stripe, :secret_key) || ENV.fetch('STRIPE_SECRET_KEY', nil)
	end

	def webhook_secret
		Rails.application.credentials.dig(:stripe, :webhook_secret) || ENV.fetch('STRIPE_WEBHOOK_SECRET', nil)
	end

	def configured?
		secret_key.present?
	end
end
