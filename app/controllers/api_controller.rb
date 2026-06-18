# frozen_string_literal: true

class ApiController < ApplicationController
	def me
		if user_signed_in?
			render json: {
				logged_in: true,
				user: UserSerializer.new(current_user).as_json
			}
		else
			render json: { logged_in: false }
		end
	end

	def csrf_token
		render json: { csrf_token: form_authenticity_token }
	end
end
