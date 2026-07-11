require 'rails_helper'

RSpec.describe 'Userback widget', type: :request do
  let(:user) { create(:user) }

  before do
    # Default: no token configured anywhere.
    allow(Rails.application.credentials).to receive(:userback_access_token).and_return(nil)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('USERBACK_ACCESS_TOKEN').and_return(nil)
  end

  it 'renders the widget for signed-in users using the credentials token' do
    allow(Rails.application.credentials).to receive(:userback_access_token).and_return('UB-creds-token')

    sign_in user
    get '/'

    expect(response.body).to include('static.userback.io')
    expect(response.body).to include('UB-creds-token')
    expect(response.body).to include(user.email)
  end

  it 'falls back to the USERBACK_ACCESS_TOKEN env var' do
    allow(ENV).to receive(:[]).with('USERBACK_ACCESS_TOKEN').and_return('UB-env-token')

    sign_in user
    get '/'

    expect(response.body).to include('UB-env-token')
  end

  it 'does not render the widget when no token is configured' do
    sign_in user
    get '/'

    expect(response.body).not_to include('static.userback.io')
  end

  it 'does not render the widget for anonymous visitors' do
    allow(Rails.application.credentials).to receive(:userback_access_token).and_return('UB-creds-token')

    get '/'

    expect(response.body).not_to include('static.userback.io')
  end
end
