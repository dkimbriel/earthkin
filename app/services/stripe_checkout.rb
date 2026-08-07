# frozen_string_literal: true

# Builds Stripe-hosted Checkout Sessions for the two things families pay for:
# the one-time enrollment fee (public token page) and tuition installments
# (parent portal). Card data never touches our servers — we create a session
# server-side and redirect the parent to Stripe's hosted page. The resulting
# payment is recorded when Stripe calls back on the webhook, keyed by the
# session id in metadata.
module StripeCheckout
	module_function

	# Enrollment fee. The fee amount is fixed regardless of tuition plan, but we
	# carry the chosen payment_plan_id so the webhook can provision the
	# enrollment against the plan the family selected.
	def enrollment_fee_session(application, payment_plan)
		amount = application.effective_enrollment_fee.to_d
		token = application.payment_selection_token

		create_session(
			amount_cents: (amount * 100).to_i,
			product_name: "Enrollment Fee — #{application.child_first_name}",
			customer_email: application.parent_email,
			success_url: "#{payment_page_url(token)}?paid=1",
			cancel_url: payment_page_url(token),
			metadata: {
				kind: 'enrollment_fee',
				application_id: application.id,
				payment_plan_id: payment_plan.id
			}
		)
	end

	# A single tuition installment from an enrollment payment plan's schedule.
	def installment_session(plan, installment_index)
		installment = plan.installments[installment_index]
		raise ArgumentError, 'No such installment' if installment.nil?

		amount = installment['amount'].to_d
		child_name = plan.program_enrollment.child&.first_name

		create_session(
			amount_cents: (amount * 100).to_i,
			product_name: "Tuition Payment — #{child_name}",
			customer_email: plan.program_enrollment.enrollment_application&.parent_email,
			success_url: "#{portal_payments_url}?paid=1",
			cancel_url: portal_payments_url,
			metadata: {
				kind: 'installment',
				enrollment_payment_plan_id: plan.id,
				installment_index: installment_index,
				program_enrollment_id: plan.program_enrollment_id
			}
		)
	end

	# --- helpers ---

	def create_session(amount_cents:, product_name:, customer_email:, success_url:, cancel_url:, metadata:)
		Stripe::Checkout::Session.create(
			mode: 'payment',
			customer_email: customer_email,
			line_items: [{
				quantity: 1,
				price_data: {
					currency: 'usd',
					unit_amount: amount_cents,
					product_data: { name: product_name }
				}
			}],
			# Ask Stripe to email its hosted receipt to the payer.
			payment_intent_data: { receipt_email: customer_email },
			success_url: success_url,
			cancel_url: cancel_url,
			metadata: metadata
		)
	end

	def url_options
		Rails.application.config.action_mailer.default_url_options || { host: 'localhost', port: 3000 }
	end

	def payment_page_url(token)
		Rails.application.routes.url_helpers.payment_selection_url(token, **url_options)
	end

	def portal_payments_url
		# React Router route inside the SPA served from root (Dashboard mounts
		# ParentPaymentsPage at /payments).
		root = Rails.application.routes.url_helpers.root_url(**url_options)
		"#{root.chomp('/')}/payments"
	end
end
