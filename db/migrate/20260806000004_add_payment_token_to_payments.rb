class AddPaymentTokenToPayments < ActiveRecord::Migration[7.0]
	def change
		# Unguessable token behind the public "pay this invoice" link emailed to
		# families. The link mints a fresh Stripe Checkout Session on click, so it
		# never expires the way a raw Stripe session URL would.
		add_column :payments, :payment_token, :string
		add_index :payments, :payment_token, unique: true, where: 'payment_token IS NOT NULL'
	end
end
