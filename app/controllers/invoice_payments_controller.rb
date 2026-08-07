class InvoicePaymentsController < ApplicationController
  layout 'public'

  # Landing page for the emailed invoice link. Shows the amount and a "Pay"
  # button; if the payment already went through it shows a paid state, and if
  # the parent has just returned from Stripe it shows a "confirming" state
  # (the webhook is the authoritative marker and may land a moment later).
  def show
    @payment = find_payment
    @state = if @payment.status == 'completed'
               :paid
             elsif params[:paid].present?
               :processing
             else
               :unpaid
             end
  end

  # Mints a fresh Stripe Checkout Session and hands off to Stripe's hosted page.
  def checkout
    @payment = find_payment
    return redirect_to(invoice_payment_path(@payment.payment_token)) if @payment.status == 'completed'

    session = StripeCheckout.invoice_session(@payment)
    redirect_to session.url, status: :see_other, allow_other_host: true
  rescue Stripe::StripeError => e
    Rails.logger.error("[invoice checkout] #{e.class}: #{e.message}")
    flash[:error] = 'We could not start the payment. Please try again or contact the school.'
    redirect_to invoice_payment_path(@payment.payment_token)
  end

  private

  def find_payment
    Payment.includes(program_enrollment: [:program, { child: { family: :parents } }])
           .find_by!(payment_token: params[:token])
  end
end
