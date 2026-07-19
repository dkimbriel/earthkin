# frozen_string_literal: true

module Api
	class ChildrenController < BaseController
		def index
			children = Child.includes(:family, :programs).order(:last_name, :first_name)
			children = children.where(family_id: params[:family_id]) if params[:family_id].present?
			render json: children.as_json(include: %i[family programs])
		end

		def show
			child = Child.includes(:family, :program_enrollments).find(params[:id])
			render json: child.as_json(include: [:family, { program_enrollments: { include: :program } }])
		end

		def create
			child = Child.create!(child_params)
			render json: child.as_json(include: :family), status: :created
		end

		def update
			child = Child.find(params[:id])
			child.update!(child_params)
			render json: child.as_json(include: :family)
		end

		def destroy
			child = Child.find(params[:id])
			child.soft_delete!
			head :no_content
		end

		private

		def child_params
			params.require(:child).permit(:family_id, :first_name, :last_name, :date_of_birth)
		end
	end
end
