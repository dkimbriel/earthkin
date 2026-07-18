class PaymentSelectionsController < ApplicationController
  layout 'public'

  # The Venmo handle families send the enrollment fee to. Set VENMO_HANDLE in
  # the environment; falls back to the school's current handle.
  helper_method :venmo_handle
  def venmo_handle
    ENV.fetch('VENMO_HANDLE', '@earthkin')
  end

  def show
    @application = EnrollmentApplication.includes(:program).find_by!(payment_selection_token: params[:token])
    @payment_plans = PaymentPlan.where(active: true).order(:display_order)
    @program = @application.program

    # Check if already paid
    if @application.status == 'fee_paid' || @application.status == 'enrolled'
      render :already_paid
      return
    end

    # Check if in correct status for payment
    unless @application.status == 'fee_requested'
      render :invalid_status
      return
    end
  end

  def confirm
    @application = EnrollmentApplication.find_by!(payment_selection_token: params[:token])
    @payment_plans = PaymentPlan.where(active: true).order(:display_order)
    @program = @application.program

    # Check if already paid
    if @application.status == 'fee_paid' || @application.status == 'enrolled'
      render :already_paid
      return
    end

    # Check if in correct status
    unless @application.status == 'fee_requested'
      render :invalid_status
      return
    end

    # Validate payment plan selection
    payment_plan = PaymentPlan.find_by(id: params[:payment_plan_id], active: true)
    unless payment_plan
      flash[:error] = 'Please select a payment plan to continue'
      render :show
      return
    end

    # Record the family's chosen plan. Payment is made out-of-band (Venmo),
    # so we do NOT mark the fee paid or provision the enrollment here — the
    # school confirms receipt and records the fee (via Record Fee Payment),
    # which locks in the plan and creates the enrollment, schedule, and login.
    @application.update!(selected_payment_plan: payment_plan)
    AdminNotifier.payment_plan_selected(@application, payment_plan)
    render :confirmed
  end
end
