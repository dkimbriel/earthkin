# frozen_string_literal: true

module Api
	class BaseController < ApplicationController
		before_action :authenticate_user!
		before_action :require_staff!

		rescue_from ActiveRecord::RecordNotFound, with: :not_found
		rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity

		private

		# Internal portal APIs are for staff (admins and teachers). Actions that
		# skip authenticate_user! (public forms) pass through with no user.
		def require_staff!
			return unless current_user

			render json: { error: 'Forbidden' }, status: :forbidden unless current_user.staff?
		end

		def require_admin!
			render json: { error: 'Forbidden' }, status: :forbidden unless current_user&.admin?
		end

		def not_found
			render json: { error: 'Record not found' }, status: :not_found
		end

		def unprocessable_entity(exception)
			render json: { errors: exception.record.errors.full_messages }, status: :unprocessable_content
		end
	end
end
