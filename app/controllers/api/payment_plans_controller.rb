module Api
  class PaymentPlansController < BaseController
    def index
      plans = PaymentPlan.includes(:program).order(:display_order)
      plans = plans.where(program_id: params[:program_id]) if params[:program_id].present?
      plans = plans.active if params[:active] == 'true'

      # Include auto-generated schedule based on program start date
      render json: plans.map { |plan|
        plan.as_json(include: :program).merge(
          installment_schedule: plan.preview_schedule(plan.program.start_date || Date.current)
        )
      }
    end

    def show
      plan = PaymentPlan.find(params[:id])
      render json: plan
    end

    def create
      plan = PaymentPlan.create!(plan_params)
      render json: plan, status: :created
    end

    def update
      plan = PaymentPlan.find(params[:id])
      plan.update!(plan_params)
      render json: plan
    end

    def destroy
      plan = PaymentPlan.find(params[:id])

      if plan.enrollment_payment_plans.exists?
        render json: { error: "Cannot delete payment plan that is in use by #{plan.enrollment_payment_plans.count} enrollment(s)" }, status: :unprocessable_entity
        return
      end

      plan.soft_delete!
      head :no_content
    end

    private

    def plan_params
      params.require(:payment_plan).permit(
        :program_id, :name, :description, :installment_count,
        :total_amount, :installment_amount, :active, :display_order,
        installment_schedule: []
      )
    end
  end
end
