# frozen_string_literal: true

module Api
	class LocationsController < BaseController
		def index
			locations = Location.order(:name)
			render json: locations
		end

		def show
			location = Location.find(params[:id])
			render json: location
		end

		def create
			location = Location.create!(location_params)
			render json: location, status: :created
		end

		def update
			location = Location.find(params[:id])
			location.update!(location_params)
			render json: location
		end

		def destroy
			location = Location.find(params[:id])
			location.destroy!
			head :no_content
		end

		private

		def location_params
			params.require(:location).permit(:name, :address, :notes)
		end
	end
end
