# frozen_string_literal: true

module Api
	class ProgramsController < BaseController
		# Public, unauthenticated endpoint for the enrollment application page.
		# Returns only non-sensitive program fields (no enrollments/revenue).
		skip_before_action :authenticate_user!, only: [:public_show]
		skip_before_action :require_staff!, only: [:public_show]

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

		DAY_NAMES = %w[monday tuesday wednesday thursday friday saturday sunday].freeze

		# Bulk-create classes from a weekly pattern (e.g. every Tue/Thu between
		# the program's start and end dates), skipping holidays and dates that
		# already have a class.
		def generate_classes
			program = Program.find(params[:id])

			days = Array(params[:days_of_week]).map { |d| d.to_s.downcase } & DAY_NAMES
			days = DAY_NAMES.select { |d| program.class_days.to_s.downcase.include?(d) } if days.empty?
			if days.empty?
				return render json: { error: 'Pick at least one day of the week' }, status: :unprocessable_content
			end

			start_date = params[:start_date].present? ? Date.parse(params[:start_date].to_s) : program.start_date
			end_date = params[:end_date].present? ? Date.parse(params[:end_date].to_s) : program.end_date
			unless start_date && end_date && end_date >= start_date
				return render json: { error: 'Set a start and end date (or add them to the program)' }, status: :unprocessable_content
			end
			if end_date > start_date + 2.years
				return render json: { error: 'Date range is too large' }, status: :unprocessable_content
			end

			skip_dates = Array(params[:skip_dates]).flat_map { |d| d.to_s.split(',') }.filter_map do |d|
				Date.parse(d.strip)
			rescue Date::Error
				nil
			end

			existing_dates = program.program_classes.where.not(date: nil).pluck(:date).to_set
			created = []
			(start_date..end_date).each do |date|
				next unless days.include?(date.strftime('%A').downcase)
				next if skip_dates.include?(date) || existing_dates.include?(date)

				created << program.program_classes.create!(
					name: date.strftime('%A %b %-d'),
					date: date,
					start_time: params[:start_time].presence || program.start_time,
					end_time: params[:end_time].presence || program.end_time,
					location_id: params[:location_id].presence
				)
			end

			render json: { created_count: created.size, classes: created.as_json }, status: :created
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

			active_count = program.program_enrollments.active.count
			if active_count.positive?
				return render json: {
					error: "Cannot delete a program with #{active_count} active enrollment(s). Cancel or move them first."
				}, status: :unprocessable_entity
			end

			program.soft_delete!
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
