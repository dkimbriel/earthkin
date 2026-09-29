class AddAutopay < ActiveRecord::Migration[7.0]
	def change
		# One Stripe customer per family holds the saved payment methods.
		add_column :families, :stripe_customer_id, :string
		add_index :families, :stripe_customer_id, unique: true

		# Autopay is chosen per enrollment. Only Stripe ids and a display label
		# are stored; card and bank details stay on Stripe. The consent columns
		# record who agreed, when, and to exactly what wording.
		change_table :enrollment_payment_plans, bulk: true do |t|
			t.string :autopay_payment_method_id
			t.string :autopay_method_type
			t.string :autopay_method_label
			t.string :autopay_mandate_id
			t.datetime :autopay_enabled_at
			t.string :autopay_enabled_by
			t.text :autopay_consent_text
		end

		# Per-invoice charge attempts, so a failed charge is retried once and
		# then handed back to the parent as a Pay Now link.
		change_table :payments, bulk: true do |t|
			t.integer :autopay_attempts, null: false, default: 0
			t.date :autopay_retry_on
			t.string :autopay_error
		end
	end
end
