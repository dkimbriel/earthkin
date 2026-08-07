require 'rails_helper'

RSpec.describe 'PaymentSelections', type: :request do
  let(:program) { create(:program, start_date: Date.new(2026, 8, 24)) }
  let!(:plan) { create(:payment_plan, program: program, name: 'Monthly', installment_count: 10, total_amount: 2800) }
  let(:application) do
    create(:enrollment_application, program: program, status: 'fee_requested',
                                    payment_selection_token: 'tok-123')
  end

  describe 'GET /payment/:token' do
    it 'shows the plan selection page with a Stripe card CTA and no Venmo instructions' do
      get "/payment/#{application.payment_selection_token}"

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('Venmo')
      expect(response.body).to include('Enrollment Fee')
      expect(response.body).not_to include('Card Number') # hosted by Stripe, not our page
    end
  end

  describe 'POST /payment/:token/checkout' do
    let(:session) { double('Stripe::Checkout::Session', url: 'https://checkout.stripe.com/c/pay/cs_test_123') }

    it 'records the plan choice and redirects to Stripe Checkout' do
      expect(StripeCheckout).to receive(:enrollment_fee_session)
        .with(an_instance_of(EnrollmentApplication), plan).and_return(session)

      post "/payment/#{application.payment_selection_token}/checkout", params: { payment_plan_id: plan.id }

      expect(response).to redirect_to('https://checkout.stripe.com/c/pay/cs_test_123')
      application.reload
      expect(application.selected_payment_plan_id).to eq(plan.id)
      expect(application.status).to eq('fee_requested') # not marked paid until the webhook lands
      expect(Payment.count).to eq(0)
    end

    it 'requires a plan selection' do
      post "/payment/#{application.payment_selection_token}/checkout", params: {}
      expect(response.body).to include('select a payment plan')
    end
  end
end
