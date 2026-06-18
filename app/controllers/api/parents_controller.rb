# frozen_string_literal: true

module Api
	class ParentsController < BaseController
		def index
			parents = Parent.includes(:family).order(:last_name, :first_name)
			parents = parents.where(family_id: params[:family_id]) if params[:family_id].present?
			render json: parents.as_json(include: :family)
		end

		def show
			parent = Parent.find(params[:id])
			render json: parent.as_json(include: :family)
		end

		def create
			parent = Parent.create!(parent_params)
			render json: parent.as_json(include: :family), status: :created
		end

		def update
			parent = Parent.find(params[:id])
			parent.update!(parent_params)
			render json: parent.as_json(include: :family)
		end

		def destroy
			parent = Parent.find(params[:id])
			parent.destroy!
			head :no_content
		end

		private

		def parent_params
			params.require(:parent).permit(:family_id, :first_name, :last_name, :email, :phone)
		end
	end
end
