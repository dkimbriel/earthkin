# frozen_string_literal: true

module Api
	class BaseController < ApplicationController
		before_action :authenticate_user!
		before_action :require_staff!

		rescue_from ActiveRecord::RecordNotFound, with: :not_found
		rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity

		private

		# Internal portal APIs are for staff (admins and teachers) only.
		# Teachers get read-only access; admins can write. Public actions must
		# explicitly skip BOTH authenticate_user! and require_staff! — anything
		# else fails closed.
		def require_staff!
			if !current_user&.staff?
				render json: { error: 'Forbidden' }, status: :forbidden
			elsif current_user.teacher_role? && !request.get?
				render json: { error: 'Teachers have view-only access' }, status: :forbidden
			end
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
