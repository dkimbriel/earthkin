require 'rails_helper'

RSpec.describe 'PaymentSelections', type: :request do
  let(:program) { create(:program, start_date: Date.new(2026, 8, 24)) }
  let!(:plan) { create(:payment_plan, program: program, name: 'Monthly', installment_count: 10, total_amount: 2800) }
  let(:application) do
    create(:enrollment_application, program: program, status: 'fee_requested',
                                    payment_selection_token: 'tok-123')
  end

  describe 'GET /payment/:token' do
    it 'shows the plan selection page with the Venmo instructions and no card fields' do
      get "/payment/#{application.payment_selection_token}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Venmo')
      expect(response.body).not_to include('Card Number')
      expect(response.body).not_to include('Demo Mode')
    end
  end

  describe 'POST /payment/:token' do
    it 'records the plan choice without marking the fee paid or provisioning' do
      expect {
        post "/payment/#{application.payment_selection_token}", params: { payment_plan_id: plan.id }
      }.not_to change(ProgramEnrollment, :count)

      expect(response).to have_http_status(:ok)
      application.reload
      expect(application.selected_payment_plan_id).to eq(plan.id)
      expect(application.status).to eq('fee_requested') # not fee_paid
      expect(Payment.count).to eq(0)
    end

    it 'requires a plan selection' do
      post "/payment/#{application.payment_selection_token}", params: {}
      expect(response.body).to include('select a payment plan')
    end
  end
end
