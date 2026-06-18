# frozen_string_literal: true

module Api
	class FamiliesController < BaseController
		def index
			families = Family.includes(:parents, :children).order(:name)
			render json: families.as_json(include: %i[parents children])
		end

		def show
			family = Family.includes(:parents, :children).find(params[:id])
			render json: family.as_json(include: %i[parents children])
		end

		def create
			family = Family.create!(family_params)
			render json: family, status: :created
		end

		def update
			family = Family.find(params[:id])
			family.update!(family_params)
			render json: family.as_json(include: %i[parents children])
		end

		def destroy
			family = Family.find(params[:id])
			family.destroy!
			head :no_content
		end

		private

		def family_params
			params.require(:family).permit(:name)
		end
	end
end
