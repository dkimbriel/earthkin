# frozen_string_literal: true

# Emails parents a reminder on the due date of each tuition installment. Run
# once a day (see lib/tasks/payment_reminders.rake / Heroku Scheduler).
#
# For every payment plan with a pending installment due today it:
#   1. finds or creates the pending invoice (Payment) for that installment, so
#      the reminder can carry a working "Pay now" link — the same pending
#      Payment the Stripe webhook later settles (kind: 'invoice');
#   2. skips it if a reminder for that invoice already went out (idempotent, so
#      a double scheduler run never double-emails);
#   3. sends PaymentMailer#payment_due to all parents in the family.
#
# Returns the number of reminders sent.
module PaymentDueReminder
  module_function

  def run(date: Date.current, logger: Rails.logger)
    sent = 0

    due_installments(date).each do |plan, index|
      payment = ensure_installment_invoice(plan, index)
      next if reminder_already_sent?(payment)

      email = EmailTrackingService.new(payment).send_email('PaymentMailer', 'payment_due', [payment.id])
      sent += 1 if email&.status == 'sent'
    rescue StandardError => e
      # One bad plan must not stop reminders for everyone else.
      logger.error("[payment reminders] plan #{plan.id} installment #{index}: #{e.class}: #{e.message}")
    end

    logger.info("[payment reminders] sent #{sent} reminder(s) for #{date}")
    sent
  end

  # [[plan, installment_index], ...] for pending installments due on `date`,
  # skipping cancelled or soft-deleted enrollments.
  def due_installments(date)
    EnrollmentPaymentPlan
      .includes(program_enrollment: { child: { family: :parents } })
      .flat_map do |plan|
        enrollment = plan.program_enrollment
        next [] if enrollment.nil? || enrollment.status == 'cancelled' || enrollment.cancelled_at.present?

        plan.installments.each_with_index.filter_map do |installment, index|
          next unless installment['status'] == 'pending'
          next if installment['due_date'].blank?
          next unless Date.parse(installment['due_date'].to_s) == date

          [plan, index]
        end
      end
  end

  # Reuses an existing (non-refunded) invoice for this installment if one is
  # already on file, otherwise creates a pending one carrying the installment
  # number so the webhook can flip the schedule when it's paid.
  def ensure_installment_invoice(plan, index)
    existing = plan.payments
                   .where(payment_type: 'tuition', installment_number: index + 1)
                   .where.not(status: 'refunded')
                   .order(:created_at).last
    return existing if existing

    installment = plan.installments[index]
    plan.payments.create!(
      program_enrollment_id: plan.program_enrollment_id,
      payment_type: 'tuition',
      amount: installment['amount'],
      payment_date: Date.parse(installment['due_date'].to_s),
      status: 'pending',
      installment_number: index + 1
    )
  end

  def reminder_already_sent?(payment)
    payment.emails.by_type('payment_due').where(status: %w[queued sent]).exists?
  end
end
