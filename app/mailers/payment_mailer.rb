class PaymentMailer < ApplicationMailer
  def invoice(payment_id)
    @payment = Payment.includes(
      program_enrollment: {
        child: { family: :parents },
        program: {},
        enrollment_payment_plan: :payment_plan
      }
    ).find(payment_id)

    @child = @payment.program_enrollment.child
    @family = @child.family
    @program = @payment.program_enrollment.program

    # Durable "Pay now" link (Stripe Checkout) instead of a static PDF invoice.
    @pay_url = @payment.pay_url

    # Send to all parents in the family
    parent_emails = @family.parents.pluck(:email).compact

    mail(
      to: parent_emails,
      subject: "Payment Invoice - #{@child.first_name} #{@child.last_name}"
    )
  end

  # Reminder sent on the due date of a tuition installment. Shows the amount
  # due with a secure pay link, the outstanding balance, and a payment history
  # linking every installment invoice plus the enrollment fee. The passed
  # payment is the pending invoice for the installment that's due today.
  def payment_due(payment_id)
    @payment = Payment.includes(
      program_enrollment: {
        child: { family: :parents },
        program: {},
        enrollment_payment_plan: :payment_plan
      }
    ).find(payment_id)

    @child = @payment.program_enrollment.child
    @family = @child.family
    @program = @payment.program_enrollment.program
    @plan = @payment.enrollment_payment_plan || @payment.program_enrollment.enrollment_payment_plan
    @pay_url = @payment.pay_url

    @total_paid = @plan.total_paid
    # Tuition still owed plus the fee if it hasn't been paid. Computed from the
    # fee flag rather than total_amount + fee - total_paid so it stays correct
    # whether or not the paid fee has its own Payment row.
    @remaining = (@plan.total_amount - @plan.tuition_paid) +
                 (@plan.enrollment_fee_paid? ? 0 : @plan.enrollment_fee)
    @invoice_rows = build_invoice_rows(@plan)

    parent_emails = @family.parents.pluck(:email).compact

    mail(
      to: parent_emails,
      subject: "Payment Due - #{@child.first_name} #{@child.last_name}"
    )
  end

  def receipt(payment_id)
    @payment = Payment.includes(
      program_enrollment: {
        child: { family: :parents },
        program: {},
        enrollment_payment_plan: :payment_plan
      }
    ).find(payment_id)

    @child = @payment.program_enrollment.child
    @family = @child.family
    @program = @payment.program_enrollment.program

    # Generate PDF
    pdf = ReceiptPdfGenerator.new(@payment).generate

    # Attach PDF
    attachments["Receipt_#{@payment.id.split('-').first.upcase}.pdf"] = pdf

    # Send to all parents in the family
    parent_emails = @family.parents.pluck(:email).compact

    mail(
      to: parent_emails,
      subject: "Payment Receipt - #{@child.first_name} #{@child.last_name}"
    )
  end

  private

  # Builds the "Payment History" rows for the reminder: the enrollment fee
  # first, then every installment in the plan's schedule. Each row carries a
  # pay/receipt link when an invoice (Payment) exists for it — paid installments
  # and the one due today always do; not-yet-invoiced future installments don't.
  def build_invoice_rows(plan)
    tuition = plan.payments
                  .where(payment_type: 'tuition')
                  .where.not(status: 'refunded')
                  .index_by(&:installment_number)
    fee_payment = plan.payments
                      .where(payment_type: 'enrollment_fee')
                      .where.not(status: 'refunded')
                      .order(:created_at).last

    rows = [{
      label: 'Enrollment Fee',
      due_date: nil,
      amount: plan.enrollment_fee,
      status: plan.enrollment_fee_paid? ? 'Paid' : 'Due',
      url: fee_payment&.pay_url,
      current: false
    }]

    plan.installments.each_with_index.map do |installment, index|
      payment = tuition[index + 1]
      current = payment&.id == @payment.id
      rows << {
        label: "Installment ##{index + 1}",
        due_date: installment['due_date'],
        amount: installment['amount'],
        status: current ? 'Due soon' : installment_status(installment),
        url: payment&.pay_url,
        current: current
      }
    end

    rows
  end

  def installment_status(installment)
    return 'Paid' if installment['status'] == 'completed'

    Date.parse(installment['due_date'].to_s) < Date.current ? 'Overdue' : 'Upcoming'
  end
end
