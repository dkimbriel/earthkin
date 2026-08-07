# frozen_string_literal: true

module Webhooks
	# Receives Stripe webhook callbacks. This is the authoritative point where a
	# card payment becomes a recorded Payment — the parent's redirect back from
	# Stripe is cosmetic. Public and unauthenticated; trust is established by
	# verifying Stripe's signature against the endpoint's signing secret.
	#
	# Inherits from ActionController::Base (not the app's authenticated API base)
	# so there's no session/CSRF/auth in the way.
	class StripeController < ActionController::Base
		# Stripe posts server-to-server with no CSRF token; trust comes from the
		# signature check in verified_event, not the session.
		skip_forgery_protection

		# checkout.session.completed is the only event we act on today; others are
		# acknowledged with 200 so Stripe stops retrying them.
		def create
			event = verified_event
			return head(:bad_request) if event.nil?

			if event.type == 'checkout.session.completed'
				handle_checkout_completed(event.data.object)
			end

			head :ok
		rescue StandardError => e
			# Log and 500 so Stripe retries — but never leak details to the caller.
			Rails.logger.error("[stripe webhook] #{e.class}: #{e.message}")
			head :internal_server_error
		end

		private

		def verified_event
			payload = request.body.read
			sig = request.env['HTTP_STRIPE_SIGNATURE']
			Stripe::Webhook.construct_event(payload, sig, StripeConfig.webhook_secret)
		rescue JSON::ParserError, Stripe::SignatureVerificationError => e
			Rails.logger.warn("[stripe webhook] rejected: #{e.class}: #{e.message}")
			nil
		end

		def handle_checkout_completed(session)
			# Idempotency: Stripe retries deliveries, so bail if we've already
			# recorded a payment for this checkout session.
			return if Payment.exists?(stripe_checkout_session_id: session.id)

			metadata = session.metadata || {}
			stripe_ids = {
				session_id: session.id,
				payment_intent_id: session.payment_intent,
				receipt_url: receipt_url_for(session.payment_intent)
			}

			case metadata['kind']
			when 'enrollment_fee'
				record_enrollment_fee(metadata, stripe_ids)
			when 'installment'
				record_installment(metadata, stripe_ids)
			when 'invoice'
				record_invoice(metadata, stripe_ids)
			else
				Rails.logger.warn("[stripe webhook] unknown checkout kind: #{metadata['kind'].inspect}")
			end
		end

		def record_enrollment_fee(metadata, stripe_ids)
			application = EnrollmentApplication.find_by(id: metadata['application_id'])
			return if application.nil?
			# Terminal states already have (or can't take) a fee payment.
			return if %w[declined enrolled].include?(application.status)

			EnrollmentWorkflowService.new(application).process_enrollment_fee_payment(
				payment_plan_id: metadata['payment_plan_id'],
				payment_method: 'stripe',
				stripe: stripe_ids
			)
		end

		def record_installment(metadata, stripe_ids)
			plan = EnrollmentPaymentPlan.find_by(id: metadata['enrollment_payment_plan_id'])
			return if plan.nil?

			index = metadata['installment_index'].to_i
			installment = plan.installments[index]
			# Skip if the installment is missing or already settled.
			return if installment.nil? || installment['status'] == 'completed'

			PaymentRecorder.record_installment(
				plan,
				installment_index: index,
				amount: installment['amount'],
				payment_method: 'stripe',
				stripe: stripe_ids
			)
		end

		# An emailed invoice was paid: mark that existing pending Payment completed
		# and, if it belongs to an installment schedule, flip the installment too.
		def record_invoice(metadata, stripe_ids)
			payment = Payment.find_by(id: metadata['payment_id'])
			return if payment.nil? || payment.status == 'completed'

			ActiveRecord::Base.transaction do
				payment.update!(
					status: 'completed',
					payment_method: 'stripe',
					payment_date: Date.current,
					stripe_checkout_session_id: stripe_ids[:session_id],
					stripe_payment_intent_id: stripe_ids[:payment_intent_id],
					stripe_receipt_url: stripe_ids[:receipt_url]
				)

				plan = payment.enrollment_payment_plan
				if plan && payment.installment_number
					index = payment.installment_number - 1
					plan.mark_installment_paid!(index, payment) if plan.installments[index]
				end
			end
		end

		# The hosted receipt lives on the charge behind the payment intent.
		def receipt_url_for(payment_intent_id)
			return nil if payment_intent_id.blank?

			intent = Stripe::PaymentIntent.retrieve(id: payment_intent_id, expand: ['latest_charge'])
			intent.latest_charge&.receipt_url
		rescue Stripe::StripeError => e
			Rails.logger.warn("[stripe webhook] could not fetch receipt: #{e.message}")
			nil
		end
	end
end
