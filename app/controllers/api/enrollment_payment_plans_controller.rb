module Api
  class EnrollmentPaymentPlansController < BaseController
    def show
      plan = EnrollmentPaymentPlan.includes(:payment_plan, :program_enrollment, :payments)
                                  .find(params[:id])
      render json: plan.as_json(
        include: [:payment_plan, :program_enrollment, :payments],
        methods: [:total_paid]
      )
    end

    def create
      enrollment_plan = EnrollmentPaymentPlan.new(enrollment_plan_params)

      # Copy installment schedule from payment plan
      payment_plan = PaymentPlan.find(enrollment_plan_params[:payment_plan_id])

      # Build installment snapshot
      enrollment_plan.installments = payment_plan.installment_schedule.map do |schedule|
        year = schedule['month'] >= 8 ? 2026 : 2027
        {
          due_date: Date.new(year, schedule['month'], schedule['day']).to_s,
          amount: schedule['amount'],
          status: 'pending',
          paid_at: nil
        }
      end

      if enrollment_plan.save
        render json: enrollment_plan, status: :created
      else
        render json: { errors: enrollment_plan.errors.full_messages },
               status: :unprocessable_entity
      end
    end

    def record_enrollment_fee
      plan = EnrollmentPaymentPlan.find(params[:id])

      # Create payment record
      payment = plan.payments.create!(
        program_enrollment_id: plan.program_enrollment_id,
        payment_type: 'enrollment_fee',
        amount: plan.enrollment_fee,
        payment_method: params[:payment_method],
        payment_date: params[:payment_date] || Date.current,
        status: 'completed',
        notes: params[:notes]
      )

      plan.mark_enrollment_fee_paid!

      # Update application and enrollment workflow status ONLY if still at fee_requested
      # Don't regress status if already past fee_paid
      application = plan.program_enrollment.enrollment_application
      if application && application.status == 'fee_requested'
        application.mark_fee_paid!
        plan.program_enrollment.advance_workflow_to!('fee_paid')
      end

      render json: plan.reload.as_json(include: :payments)
    end

    def record_installment_payment
      plan = EnrollmentPaymentPlan.find(params[:id])
      installment_index = params[:installment_index].to_i

      # Create payment record
      payment = plan.payments.create!(
        program_enrollment_id: plan.program_enrollment_id,
        payment_type: 'tuition',
        amount: params[:amount],
        payment_method: params[:payment_method],
        payment_date: params[:payment_date] || Date.current,
        status: 'completed',
        installment_number: installment_index + 1,
        notes: params[:notes]
      )

      # Update installment status
      plan.mark_installment_paid!(installment_index, payment)

      render json: plan.reload.as_json(include: :payments)
    end

    private

    def enrollment_plan_params
      params.require(:enrollment_payment_plan).permit(
        :program_enrollment_id, :payment_plan_id, :total_amount, :enrollment_fee
      )
    end
  end
end
