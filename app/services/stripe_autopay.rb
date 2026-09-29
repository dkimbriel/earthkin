# frozen_string_literal: true

# Stripe calls for autopay: the family's customer, the setup-mode Checkout
# that saves a card or bank account without charging it, and reading back a
# saved payment method. Charging lives in AutopayCharger.
module StripeAutopay
	module_function

	PAYMENT_METHOD_TYPES = %w[card us_bank_account].freeze

	# The family's Stripe customer, created on first use.
	def customer_id_for(family)
		return family.stripe_customer_id if family.stripe_customer_id.present?

		customer = Stripe::Customer.create(
			name: family.full_name,
			email: family.primary_parent&.email,
			metadata: { family_id: family.id }
		)
		family.update!(stripe_customer_id: customer.id)
		customer.id
	end

	# Hosted page where a parent saves a card or bank account for one
	# enrollment's installments. Nothing is charged; the webhook
	# (kind: autopay_setup) turns autopay on once Stripe confirms the method.
	def setup_session(plan, parent_email:)
		family = plan.program_enrollment.child.family

		Stripe::Checkout::Session.create(
			mode: 'setup',
			currency: 'usd',
			customer: customer_id_for(family),
			payment_method_types: PAYMENT_METHOD_TYPES,
			# Instant bank verification only, so the account is usable as soon as
			# the parent finishes (no multi-day micro-deposit step).
			payment_method_options: { us_bank_account: { verification_method: 'instant' } },
			success_url: "#{StripeCheckout.portal_payments_url}?autopay=1",
			cancel_url: StripeCheckout.portal_payments_url,
			metadata: {
				kind: 'autopay_setup',
				enrollment_payment_plan_id: plan.id,
				enabled_by: parent_email
			}
		)
	end

	# Details of a saved payment method for display and charging.
	def method_details(payment_method)
		payment_method = Stripe::PaymentMethod.retrieve(payment_method) if payment_method.is_a?(String)

		label =
			case payment_method.type
			when 'card'
				"#{payment_method.card.brand.to_s.titleize} ending #{payment_method.card.last4}"
			when 'us_bank_account'
				"#{payment_method.us_bank_account.bank_name.presence || 'Bank account'} ending #{payment_method.us_bank_account.last4}"
			else
				payment_method.type.to_s.humanize
			end

		{ id: payment_method.id, type: payment_method.type, label: label }
	end
end
