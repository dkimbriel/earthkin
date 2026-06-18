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

    # Generate PDF
    pdf = InvoicePdfGenerator.new(@payment).generate

    # Attach PDF
    attachments["Invoice_#{@payment.id.split('-').first.upcase}.pdf"] = pdf

    # Send to all parents in the family
    parent_emails = @family.parents.pluck(:email).compact

    mail(
      to: parent_emails,
      subject: "Payment Invoice - #{@child.first_name} #{@child.last_name}"
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
end
