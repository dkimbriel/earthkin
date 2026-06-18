require 'prawn'
require 'prawn/table'

class ReceiptPdfGenerator
  def initialize(payment)
    @payment = payment
    @enrollment = payment.program_enrollment
    @child = @enrollment.child
    @family = @child.family
    @program = @enrollment.program
    @enrollment_plan = @enrollment.enrollment_payment_plan
  end

  def generate
    Prawn::Document.new do |pdf|
      # Header
      pdf.text "EARTHKIN NATURE SCHOOL", size: 24, style: :bold, align: :center
      pdf.move_down 5
      pdf.text "Payment Receipt", size: 18, align: :center
      pdf.move_down 20

      # Receipt details
      pdf.text "Receipt Date: #{Date.current.strftime('%B %d, %Y')}"
      pdf.text "Payment Date: #{@payment.payment_date.strftime('%B %d, %Y')}"
      pdf.text "Receipt #: #{@payment.id.split('-').first.upcase}"
      pdf.move_down 20

      # Bill to section
      pdf.text "PAYMENT FROM:", style: :bold
      pdf.text @family.name
      if @family.parents.any?
        parent = @family.parents.first
        pdf.text "#{parent.first_name} #{parent.last_name}"
        pdf.text parent.email if parent.email
        pdf.text parent.phone if parent.phone
      end
      pdf.move_down 20

      # Student info
      pdf.text "STUDENT:", style: :bold
      pdf.text "#{@child.first_name} #{@child.last_name}"
      pdf.text "Program: #{@program.name}"
      pdf.move_down 20

      # Payment details table
      payment_data = [
        ["Description", "Amount Paid"],
        [payment_description, format_currency(@payment.amount)]
      ]

      pdf.table(payment_data, header: true, width: pdf.bounds.width) do
        row(0).font_style = :bold
        row(0).background_color = 'E8F5E9'
        columns(1).align = :right
      end

      pdf.move_down 20

      # Total
      pdf.text "Total Paid: #{format_currency(@payment.amount)}", size: 14, style: :bold, align: :right

      pdf.move_down 30

      # Payment method
      pdf.text "Payment Method: #{@payment.payment_method.titleize}"
      pdf.text "Payment Status: Completed", style: :bold, color: '00AA00'

      if @payment.notes.present?
        pdf.move_down 10
        pdf.text "Notes:", style: :bold
        pdf.text @payment.notes
      end

      # Footer
      pdf.move_down 40
      pdf.text "Thank you for your payment!", align: :center, style: :italic
      pdf.move_down 10
      pdf.text "Questions? Contact us at info@earthkin.com", align: :center, size: 10

      # Payment plan info if applicable
      if @enrollment_plan
        pdf.move_down 20
        pdf.stroke_horizontal_rule
        pdf.move_down 10
        pdf.text "PAYMENT PLAN SUMMARY", style: :bold
        pdf.move_down 5
        pdf.text "Plan: #{@enrollment_plan.payment_plan.name}"
        pdf.text "Total Tuition: #{format_currency(@enrollment_plan.total_amount)}"
        pdf.text "Total Paid to Date: #{format_currency(@enrollment_plan.total_paid + (@enrollment_plan.enrollment_fee_paid? ? @enrollment_plan.enrollment_fee : 0))}"

        remaining = @enrollment_plan.total_amount - @enrollment_plan.total_paid
        if remaining > 0
          pdf.text "Remaining Balance: #{format_currency(remaining)}", style: :bold
        else
          pdf.text "Account Paid in Full", style: :bold, color: '00AA00'
        end
      end
    end.render
  end

  private

  def payment_description
    case @payment.payment_type
    when 'enrollment_fee'
      "Non-refundable Enrollment Fee"
    when 'tuition'
      if @payment.installment_number
        "Tuition Payment - Installment ##{@payment.installment_number}"
      else
        "Tuition Payment"
      end
    else
      "Payment"
    end
  end

  def format_currency(amount)
    "$#{sprintf('%.2f', amount)}"
  end
end