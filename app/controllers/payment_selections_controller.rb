class PaymentSelectionsController < ApplicationController
  layout 'public'

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
      flash[:error] = 'Please select a valid payment plan'
      render :show
      return
    end

    # Validate demo payment form (basic validation)
    unless valid_demo_payment_params?
      flash[:error] = 'Please fill in all payment fields'
      render :show
      return
    end

    # Parse payment start date (defaults to program start date or current date)
    payment_start_date = if params[:payment_start_date].present?
                           Date.parse(params[:payment_start_date])
                         else
                           @program.start_date || Date.current
                         end

    begin
      ActiveRecord::Base.transaction do
        # 1. Store the selected payment plan
        @application.update!(selected_payment_plan: payment_plan)

        # 2. Process the enrollment fee payment using the existing workflow service
        service = EnrollmentWorkflowService.new(@application)
        service.process_enrollment_fee_payment(
          payment_plan_id: payment_plan.id,
          payment_method: 'card',
          payment_date: Date.current,
          payment_start_date: payment_start_date,
          notes: "Online payment via payment selection page. Card ending in #{params[:card_number]&.last(4)}"
        )
      end

      render :confirmed
    rescue StandardError => e
      Rails.logger.error "Payment selection failed: #{e.message}"
      flash[:error] = 'There was an error processing your payment. Please try again.'
      render :show
    end
  end

  private

  def valid_demo_payment_params?
    params[:payment_plan_id].present? &&
      params[:card_number].present? &&
      params[:card_expiry].present? &&
      params[:card_cvv].present? &&
      params[:cardholder_name].present?
  end
end
