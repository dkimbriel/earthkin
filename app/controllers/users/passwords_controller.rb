# frozen_string_literal: true

class Users::PasswordsController < Devise::PasswordsController
  respond_to :json

  # POST /users/password
  def create
    self.resource = resource_class.send_reset_password_instructions(resource_params)
    yield resource if block_given?

    if successfully_sent?(resource)
      render json: {
        status: { code: 200, message: 'Password reset instructions sent to your email.' }
      }, status: :ok
    else
      render json: {
        status: { code: 422, message: 'Email not found.' },
        errors: resource.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # PUT /users/password
  def update
    self.resource = resource_class.reset_password_by_token(resource_params)
    yield resource if block_given?

    if resource.errors.empty?
      resource.unlock_access! if unlockable?(resource)
      render json: {
        status: { code: 200, message: 'Password has been reset successfully.' }
      }, status: :ok
    else
      render json: {
        status: { code: 422, message: 'Password reset failed.' },
        errors: resource.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  private

  def resource_params
    params.require(:user).permit(:email, :password, :password_confirmation, :reset_password_token)
  end
end
