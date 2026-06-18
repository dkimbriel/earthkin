# frozen_string_literal: true

module Api
	class ProgramClassesController < BaseController
		before_action :ensure_class_not_in_past, only: %i[update destroy]

		def index
			program_classes = ProgramClass.includes(:program, :location, :teachers).order(:date, :start_time)
			program_classes = program_classes.where(program_id: params[:program_id]) if params[:program_id]
			render json: program_classes.as_json(
				include: [
					:program,
					:location,
					{ teachers: { methods: %i[avatar_url full_name] } }
				]
			)
		end

		def show
			program_class = ProgramClass.includes(:location, :teachers).find(params[:id])
			render json: program_class.as_json(
				include: [
					:program,
					:location,
					{ teachers: { methods: %i[avatar_url full_name] } }
				]
			)
		end

		def assign_teacher
			program_class = ProgramClass.find(params[:id])
			teacher = Teacher.find(params[:teacher_id])
			program_class.teachers << teacher unless program_class.teachers.include?(teacher)
			render json: { success: true, teachers: program_class.teachers.as_json(methods: %i[avatar_url full_name]) }
		end

		def unassign_teacher
			program_class = ProgramClass.find(params[:id])
			program_class.program_class_teachers.find_by(teacher_id: params[:teacher_id])&.destroy
			render json: { success: true, teachers: program_class.teachers.as_json(methods: %i[avatar_url full_name]) }
		end

		def create
			program_class = ProgramClass.create!(program_class_params)
			render json: program_class.as_json(include: %i[program location]), status: :created
		end

		def update
			program_class = ProgramClass.find(params[:id])
			program_class.update!(program_class_params)
			render json: program_class.as_json(include: %i[program location])
		end

		def destroy
			program_class = ProgramClass.find(params[:id])
			program_class.destroy!
			head :no_content
		end

		private

		def ensure_class_not_in_past
			program_class = ProgramClass.find(params[:id])
			return if program_class.date.nil? || program_class.date >= Date.current

			render json: { error: 'Cannot modify a class that has already occurred' }, status: :unprocessable_entity
		end

		def program_class_params
			params.require(:program_class).permit(:program_id, :name, :date, :start_time, :end_time, :location_id)
		end
	end
end
