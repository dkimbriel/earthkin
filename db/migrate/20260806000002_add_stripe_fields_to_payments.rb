class AddStripeFieldsToPayments < ActiveRecord::Migration[7.0]
	def change
		# Stripe identifiers for card payments. checkout_session_id is the
		# idempotency key: the webhook records a payment only if none exists yet
		# for its session (Stripe retries webhook deliveries). receipt_url is
		# Stripe's hosted receipt, surfaced in the parent portal.
		add_column :payments, :stripe_checkout_session_id, :string
		add_column :payments, :stripe_payment_intent_id, :string
		add_column :payments, :stripe_receipt_url, :string

		add_index :payments, :stripe_checkout_session_id, unique: true,
		          where: 'stripe_checkout_session_id IS NOT NULL'
	end
end
