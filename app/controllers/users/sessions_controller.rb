# frozen_string_literal: true

class Users::SessionsController < Devise::SessionsController
	respond_to :json

	# A sign-in request must always authenticate the submitted credentials.
	# Otherwise warden returns the already-authenticated session user, so if a
	# previous sign-out never reached the server (e.g. failed CSRF), "signing
	# in" as a different account silently keeps the old session.
	def create
		sign_out(:user) if user_signed_in?
		super
	end

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
