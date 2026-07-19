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

	# On a parent's very first successful sign-in, stamp the time and alert
	# admins so they know the family is in and forms can be issued. Best-effort:
	# never let a hiccup here block the login.
	def record_first_sign_in(user)
		return if user.first_signed_in_at.present?

		user.update_column(:first_signed_in_at, Time.current)
		AdminNotifier.family_first_login(user) if user.parent_role?
	rescue StandardError => e
		Rails.logger.error("record_first_sign_in failed: #{e.class} #{e.message}")
	end

	def respond_with(resource, _opts = {})
	if resource.persisted?
		record_first_sign_in(resource)
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
