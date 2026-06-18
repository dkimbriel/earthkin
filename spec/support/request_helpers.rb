module RequestHelpers
  include Warden::Test::Helpers

  def sign_in(user)
    login_as(user, scope: :user)
  end
end

RSpec.configure do |config|
  config.include RequestHelpers, type: :request
  config.include Devise::Test::IntegrationHelpers, type: :request

  config.after(:each, type: :request) do
    Warden.test_reset!
  end
end
