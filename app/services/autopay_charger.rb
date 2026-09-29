# frozen_string_literal: true

# Charges autopay families' tuition installments on their due dates. Runs
# daily with the payment reminders (lib/tasks/payment_reminders.rake).
#
# For each enrollment with autopay on, every pending installment that is due
# today or earlier, and fell due after autopay was turned on (it never reaches
# back to charge an old overdue one by surprise), is charged off-session with
# the saved card or bank account against its pending invoice (the same
# Payment the reminder email links to):
#   - card succeeded   -> invoice and installment marked paid now
#   - bank processing  -> left pending; the webhook settles it in a few days
#   - failed, 1st time -> retried RETRY_AFTER_DAYS later
#   - failed, 2nd time -> the parent is emailed a Pay Now link, admins notified
#
# Set AUTOPAY_DRY_RUN=1 to log what would be charged without calling Stripe.
module AutopayCharger
	module_function

	MAX_ATTEMPTS = 2
	RETRY_AFTER_DAYS = 3

	def run(date: Date.current, dry_run: ENV['AUTOPAY_DRY_RUN'] == '1', logger: Rails.logger)
		results = Hash.new(0)

		due_charges(date).each do |plan, index|
			invoice = PaymentDueReminder.ensure_installment_invoice(plan, index)
			next unless chargeable?(invoice, date)

			if dry_run
				logger.info("[autopay] DRY RUN would charge $#{invoice.amount} to #{plan.autopay_method_label} (plan #{plan.id}, installment #{index + 1})")
				results[:dry_run] += 1
				next
			end

			results[charge(plan, invoice, date)] += 1
		rescue StandardError => e
			# One bad plan must not stop charges for everyone else.
			logger.error("[autopay] plan #{plan.id} installment #{index + 1}: #{e.class}: #{e.message}")
			results[:error] += 1
		end

		logger.info("[autopay] #{date}: #{results.to_h.inspect}")
		results
	end

	# [[plan, installment_index], ...] to consider charging today.
	def due_charges(date)
		EnrollmentPaymentPlan.where.not(autopay_payment_method_id: nil)
		                     .includes(program_enrollment: { child: :family })
		                     .flat_map do |plan|
			enrollment = plan.program_enrollment
			next [] if enrollment.nil? || enrollment.status == 'cancelled' || enrollment.cancelled_at.present?

			enabled_on = plan.autopay_enabled_at.to_date
			plan.installments.each_with_index.filter_map do |installment, index|
				next if installment['status'] == 'completed' || installment['paid_at'].present?

				due = Date.parse(installment['due_date'].to_s)
				[plan, index] if due <= date && due >= enabled_on
			rescue ArgumentError, TypeError
				nil
			end
		end
	end

	# Skip an invoice that's paid, already processing, waiting for its retry
	# date, or out of attempts (the parent has been sent a Pay Now link).
	def chargeable?(invoice, date)
		return false if invoice.status == 'completed'
		return false if invoice.autopay_attempts >= MAX_ATTEMPTS
		return false if invoice.autopay_retry_on && invoice.autopay_retry_on > date
		return false if invoice.stripe_payment_intent_id.present? && invoice.autopay_error.blank?

		true
	end

	def charge(plan, invoice, date)
		attempt = invoice.autopay_attempts + 1
		intent = Stripe::PaymentIntent.create(
			intent_params(plan, invoice),
			{ idempotency_key: "autopay-#{invoice.id}-#{attempt}" }
		)

		case intent.status
		when 'succeeded'
			PaymentRecorder.complete_invoice(
				invoice.tap { |i| i.autopay_attempts = attempt },
				stripe: { payment_intent_id: intent.id, receipt_url: intent.latest_charge&.receipt_url }
			)
			AdminNotifier.payment_completed(invoice)
			:charged
		when 'processing'
			invoice.update!(autopay_attempts: attempt, stripe_payment_intent_id: intent.id,
			                autopay_error: nil, autopay_retry_on: nil)
			:processing
		else
			record_failure(invoice, attempt, date, "Payment needs attention (#{intent.status.humanize.downcase})")
		end
	rescue Stripe::CardError => e
		# Declines, expired cards, authentication required. Anything else (a bad
		# request, a network error) is our problem, not the family's: it's
		# logged by run and tried again tomorrow without counting as an attempt,
		# so a bug can never email families that their payment failed.
		record_failure(invoice, attempt, date, e.message)
	end

	def intent_params(plan, invoice)
		enrollment = plan.program_enrollment
		params = {
			amount: (invoice.amount.to_d * 100).round.to_i,
			currency: 'usd',
			customer: enrollment.child.family.stripe_customer_id,
			payment_method: plan.autopay_payment_method_id,
			payment_method_types: [plan.autopay_method_type],
			off_session: true,
			confirm: true,
			description: "Tuition installment ##{invoice.installment_number} — #{enrollment.child.first_name}",
			receipt_email: enrollment.child.family.primary_parent&.email,
			metadata: { kind: 'autopay', payment_id: invoice.id, enrollment_payment_plan_id: plan.id },
			expand: ['latest_charge']
		}
		params[:mandate] = plan.autopay_mandate_id if plan.autopay_mandate_id.present?
		params.compact
	end

	# Public so the webhook can report an asynchronous (bank) failure the same way.
	def record_failure(invoice, attempt, date, message)
		final = attempt >= MAX_ATTEMPTS
		invoice.update!(
			autopay_attempts: attempt,
			autopay_error: message.to_s.truncate(250),
			autopay_retry_on: final ? nil : date + RETRY_AFTER_DAYS,
			stripe_payment_intent_id: nil
		)

		if final
			EmailTrackingService.new(invoice).send_email('PaymentMailer', 'autopay_failed', [invoice.id])
			AdminNotifier.autopay_failed(invoice)
		end

		final ? :failed : :retrying
	end
end
