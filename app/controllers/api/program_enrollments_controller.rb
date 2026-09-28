# frozen_string_literal: true

module Api
	class ProgramEnrollmentsController < BaseController
		def index
			enrollments = ProgramEnrollment.includes(:child, :program, :payments, enrollment_payment_plan: :payment_plan).order(created_at: :desc)
			enrollments = enrollments.where(program_id: params[:program_id]) if params[:program_id]
			enrollments = enrollments.where(child_id: params[:child_id]) if params[:child_id]
			enrollments = enrollments.where(status: params[:status]) if params[:status]
			render json: enrollments.as_json(
				include: {
					child: {},
					program: {},
					enrollment_payment_plan: { include: :payment_plan }
				},
				methods: %i[total_owed total_paid balance_due]
			)
		end

		def show
			enrollment = ProgramEnrollment.includes(:child, :program, :payments, enrollment_payment_plan: :payment_plan).find(params[:id])
			render json: enrollment.as_json(
				include: {
					child: {},
					program: {},
					payments: {},
					enrollment_payment_plan: { include: :payment_plan }
				},
				methods: %i[total_owed total_paid balance_due]
			).merge(billable_classes: enrollment.billable_classes.as_json).merge(family_emails_json(enrollment))
		end

		def create
			enrollment = ProgramEnrollment.create!(enrollment_params)
			render json: enrollment.as_json(include: %i[child program]), status: :created
		end

		def update
			enrollment = ProgramEnrollment.find(params[:id])
			enrollment.update!(enrollment_params)
			render json: enrollment.as_json(
				include: %i[child program payments],
				methods: %i[total_owed total_paid balance_due]
			)
		end

		def destroy
			enrollment = ProgramEnrollment.find(params[:id])
			enrollment.soft_delete!
			head :no_content
		end

		private

		# The family's email history, admins only (the emails API is admin-only too;
		# bodies carry pay links). Same shape as the application's Communications
		# tab so EmailTimeline renders it.
		def family_emails_json(enrollment)
			family = enrollment.child&.family
			return {} unless current_user.admin? && family

			{
				family_emails: family.emails.as_json(
					only: %i[id mailer_class email_type recipient subject status sent_at failed_at error_message created_at html_body],
					methods: %i[type_label status_color]
				)
			}
		end

		def enrollment_params
			params.require(:program_enrollment).permit(:child_id, :program_id, :status, :rate_per_class, :cancelled_at)
		end
	end
end
