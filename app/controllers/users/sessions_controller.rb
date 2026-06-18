# frozen_string_literal: true

class Users::SessionsController < Devise::SessionsController
	respond_to :json

	private

	def respond_with(resource, _opts = {})
	if resource.persisted?
		render json: {
			status: { code: 200, message: 'Logged in successfully.' },
		data: UserSerializer.new(resource).as_json
	  }, status: :ok
	else
	  render json: {
		status: { code: 401, message: 'Invalid email or password.' }
	  }, status: :unauthorized
	end
	end

	def respond_to_on_destroy
	if current_user
	  render json: {
		status: { code: 200, message: 'Logged out successfully.' }
	  }, status: :ok
	else
	  render json: {
		status: { code: 401, message: 'No active session.' }
	  }, status: :unauthorized
	end
	end
end
