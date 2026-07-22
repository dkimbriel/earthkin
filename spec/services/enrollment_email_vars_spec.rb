require 'rails_helper'

RSpec.describe EnrollmentEmailVars do
  describe '.enrollment_fee_request' do
    let(:application) { create(:enrollment_application) }

    it 'returns the payment link as an html_safe button' do
      vars = described_class.enrollment_fee_request(application)

      expect(vars[:payment_link]).to be_html_safe
      expect(vars[:payment_link]).to include('<a href=')
      expect(vars[:payment_link]).to include('Reserve Your Spot')
    end

    it 'renders the handbook url as a button when configured' do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('FAMILY_HANDBOOK_URL').and_return('https://handbook.test/guide')

      vars = described_class.enrollment_fee_request(application)

      expect(vars[:handbook_url]).to include('href="https://handbook.test/guide"')
      expect(vars[:handbook_url]).to include('Review the Family Handbook')
    end

    it 'renders nothing for the handbook when the url is unset' do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('FAMILY_HANDBOOK_URL').and_return(nil)

      vars = described_class.enrollment_fee_request(application)

      expect(vars[:handbook_url]).to eq('')
    end
  end
end
