require 'rails_helper'

# Signing in must always authenticate the submitted credentials. If a
# previous sign-out never reached the server (e.g. it failed CSRF), warden
# still holds the old session — without the sign-out-first override in
# Users::SessionsController#create, "signing in" as a different account
# silently returns the previous user.
RSpec.describe 'Sessions', type: :request do
  let!(:first_user) { create(:user, email: 'first@example.com') }
  let!(:second_user) { create(:user, email: 'second@example.com') }

  def sign_in_with(user, password: 'password123')
    post '/users/sign_in', params: { user: { email: user.email, password: password } }, as: :json
  end

  it 'signs in with valid credentials' do
    sign_in_with(first_user)

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig('data', 'email')).to eq('first@example.com')
  end

  it 'rejects invalid credentials' do
    sign_in_with(first_user, password: 'wrong')

    expect(response).to have_http_status(:unauthorized)
  end

  it 'replaces an existing session when a different account signs in' do
    sign_in_with(first_user)
    sign_in_with(second_user)

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig('data', 'email')).to eq('second@example.com')

    get '/api/current_user'
    expect(response.parsed_body.dig('user', 'email')).to eq('second@example.com')
  end

  it 'rejects a sign-in with wrong credentials even when a session is active' do
    sign_in_with(first_user)
    sign_in_with(second_user, password: 'wrong')

    expect(response).to have_http_status(:unauthorized)
  end
end
