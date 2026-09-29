# frozen_string_literal: true

module Api
	class ReportsController < BaseController
		# Per-family payment detail, so admins only (teachers don't get the
		# dashboard either).
		before_action :require_admin!

		# Dashboard cash forecast: collected and outstanding by week (see
		# WeeklyCashForecast).
		def weekly_revenue
			render json: WeeklyCashForecast.new.call
		end
	end
end
