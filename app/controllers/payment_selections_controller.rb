class PaymentSelectionsController < ApplicationController
  layout 'public'

  def show
    load_application
    return if rendered_terminal_state?
  end

  # Parent picked a plan and clicked "Pay enrollment fee". We record the chosen
  # plan (so it's known even if they abandon checkout), notify the office, then
  # send them to Stripe's hosted Checkout. The fee only counts as paid once
  # Stripe calls the webhook back — that's what provisions the enrollment.
  def checkout
    load_application
    return if rendered_terminal_state?

    payment_plan = PaymentPlan.find_by(id: params[:payment_plan_id], active: true)
    unless payment_plan
      flash[:error] = 'Please select a payment plan to continue'
      render :show
      return
    end

    @application.update!(selected_payment_plan: payment_plan)
    AdminNotifier.payment_plan_selected(@application, payment_plan)

    session = StripeCheckout.enrollment_fee_session(@application, payment_plan)
    redirect_to session.url, status: :see_other, allow_other_host: true
  rescue Stripe::StripeError => e
    Rails.logger.error("[stripe checkout] #{e.class}: #{e.message}")
    flash[:error] = 'We could not start the payment. Please try again or contact the school.'
    render :show
  end

  private

  def load_application
    @application = EnrollmentApplication.includes(:program).find_by!(payment_selection_token: params[:token])
    @payment_plans = PaymentPlan.where(active: true).order(:display_order)
    @program = @application.program
  end

  # Renders the appropriate terminal view and returns true when the application
  # isn't awaiting a fee payment, so callers can bail early.
  def rendered_terminal_state?
    if %w[fee_paid enrolled].include?(@application.status)
      render :already_paid
      true
    elsif @application.status != 'fee_requested'
      render :invalid_status
      true
    else
      false
    end
  end
end
