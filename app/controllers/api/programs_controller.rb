# frozen_string_literal: true

module Api
	class ProgramsController < BaseController
		# Public, unauthenticated endpoint for the enrollment application page.
		# Returns only non-sensitive program fields (no enrollments/revenue).
		skip_before_action :authenticate_user!, only: [:public_show]

		def public_show
			program = Program.find(params[:id])
			render json: program.as_json(
				only: %i[id name description start_date end_date class_days start_time end_time capacity enrollment_fee]
			)
		end

		def index
			programs = Program.includes(:program_classes, :teachers).order(:start_date)
			render json: programs.as_json(
				include: [:program_classes, :teachers],
				methods: %i[enrolled_count pending_count]
			)
		end

		def show
			program = Program.includes(:program_classes, :program_enrollments, :teachers).find(params[:id])
			render json: program.as_json(
				include: [
					:program_classes,
					{ program_enrollments: { include: :child } },
					{ teachers: { methods: %i[avatar_url full_name] } }
				],
				methods: %i[enrolled_count pending_count revenue_per_class]
			)
		end

		def assign_teacher
			program = Program.find(params[:id])
			teacher = Teacher.find(params[:teacher_id])
			program.teachers << teacher unless program.teachers.include?(teacher)
			render json: { success: true, teachers: program.teachers.as_json(methods: %i[avatar_url full_name]) }
		end

		def unassign_teacher
			program = Program.find(params[:id])
			program.program_teachers.find_by(teacher_id: params[:teacher_id])&.destroy
			render json: { success: true, teachers: program.teachers.as_json(methods: %i[avatar_url full_name]) }
		end

		def create
			program = Program.create!(program_params)
			render json: program, status: :created
		end

		def update
			program = Program.find(params[:id])
			program.update!(program_params)
			render json: program.as_json(methods: %i[enrolled_count pending_count revenue_per_class])
		end

		def destroy
			program = Program.find(params[:id])
			program.destroy!
			head :no_content
		end

		def send_enrollment_invite
			program = Program.find(params[:id])
			recipients = params[:recipients]

			if recipients.blank?
				render json: { error: 'At least one recipient is required' }, status: :unprocessable_entity
				return
			end

			sent_count = 0
			recipients.each do |recipient|
				next if recipient[:email].blank? || recipient[:name].blank?

				# Parse name into first and last name
				name_parts = recipient[:name].strip.split(/\s+/, 2)
				first_name = name_parts[0]
				last_name = name_parts[1] || ''

				# Create enrollment application with invited status
				application = EnrollmentApplication.create!(
					program: program,
					parent_first_name: first_name,
					parent_last_name: last_name,
					parent_email: recipient[:email],
					status: 'invited'
				)

				# Generate enrollment URL with application ID for tracking
				enrollment_url = "#{request.base_url}/enroll?program_id=#{program.id}&application_id=#{application.id}"

				# Send the email using EmailTrackingService for proper tracking
				EmailTrackingService.new(application).send_email(
					'EnrollmentMailer',
					'enrollment_invite',
					[application.id, enrollment_url]
				)

				sent_count += 1
			end

			render json: { success: true, sent_count: sent_count }
		end

		private

		def program_params
			params.require(:program).permit(:name, :description, :start_date, :end_date, :capacity,
				:enrollment_fee, :class_days, :start_time, :end_time)
		end
	end
end
