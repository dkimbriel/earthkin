# frozen_string_literal: true

# Records a tuition installment payment against an enrollment payment plan:
# creates the Payment row and flips the installment to completed. Shared by the
# admin "record installment" endpoint and the Stripe webhook so both paths
# behave identically. (The enrollment-fee equivalent lives in
# EnrollmentWorkflowService#process_enrollment_fee_payment, which also handles
# provisioning.)
module PaymentRecorder
	module_function

	def record_installment(plan, installment_index:, amount:, payment_method:, payment_date: nil, notes: nil, stripe: {})
		payment = nil

		ActiveRecord::Base.transaction do
			payment = plan.payments.create!(
				{
					program_enrollment_id: plan.program_enrollment_id,
					payment_type: 'tuition',
					amount: amount,
					payment_method: payment_method,
					payment_date: payment_date || Date.current,
					status: 'completed',
					installment_number: installment_index + 1,
					notes: notes
				}.merge(stripe_attrs(stripe))
			)

			plan.mark_installment_paid!(installment_index, payment)
		end

		payment
	end

	# Maps the stripe metadata hash onto Payment's stripe_* columns. Accepts
	# symbol keys; drops blanks so non-Stripe payments stay clean.
	def stripe_attrs(stripe)
		return {} if stripe.blank?

		{
			stripe_checkout_session_id: stripe[:session_id],
			stripe_payment_intent_id: stripe[:payment_intent_id],
			stripe_receipt_url: stripe[:receipt_url]
		}.compact
	end
end
