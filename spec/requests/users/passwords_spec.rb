require 'rails_helper'

RSpec.describe 'Users::Passwords', type: :request do
  let!(:user) { create(:user, email: 'parent@example.com', password: 'oldpassword', password_confirmation: 'oldpassword') }

  describe 'POST /users/password (forgot password)' do
    it 'emails a reset link pointing at the SPA reset page' do
      expect {
        post '/users/password', params: { user: { email: user.email } }
      }.to change { ActionMailer::Base.deliveries.count }.by(1)

      expect(response).to have_http_status(:ok)

      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to eq([user.email])
      expect(mail.body.encoded).to include('/reset-password?reset_password_token=')
    end

    it 'returns 422 for an unknown email' do
      expect {
        post '/users/password', params: { user: { email: 'nobody@example.com' } }
      }.not_to change { ActionMailer::Base.deliveries.count }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'PUT /users/password (reset password)' do
    it 'resets the password with a valid token' do
      raw_token = user.send_reset_password_instructions

      put '/users/password', params: {
        user: {
          reset_password_token: raw_token,
          password: 'newpassword123',
          password_confirmation: 'newpassword123'
        }
      }

      expect(response).to have_http_status(:ok)
      expect(user.reload.valid_password?('newpassword123')).to be true
    end

    it 'rejects an invalid token' do
      put '/users/password', params: {
        user: {
          reset_password_token: 'bogus',
          password: 'newpassword123',
          password_confirmation: 'newpassword123'
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(user.reload.valid_password?('oldpassword')).to be true
    end
  end
end
