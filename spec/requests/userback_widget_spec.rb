require 'rails_helper'

RSpec.describe 'Userback widget', type: :request do
  let(:user) { create(:user) }

  it 'renders the widget for signed-in users when the token is configured' do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('USERBACK_ACCESS_TOKEN').and_return('UB-test-token')

    sign_in user
    get '/'

    expect(response.body).to include('static.userback.io')
    expect(response.body).to include('UB-test-token')
    expect(response.body).to include(user.email)
  end

  it 'does not render the widget when no token is configured' do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('USERBACK_ACCESS_TOKEN').and_return(nil)

    sign_in user
    get '/'

    expect(response.body).not_to include('static.userback.io')
  end

  it 'does not render the widget for anonymous visitors' do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('USERBACK_ACCESS_TOKEN').and_return('UB-test-token')

    get '/'

    expect(response.body).not_to include('static.userback.io')
  end
end
