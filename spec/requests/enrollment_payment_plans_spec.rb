require 'rails_helper'

RSpec.describe 'Api::EnrollmentPaymentPlans', type: :request do
  let(:user) { create(:user) }
  let(:program) { create(:program) }
  let(:payment_plan) { create(:payment_plan, program: program) }
  let(:enrollment) { create(:program_enrollment, program: program) }

  before { sign_in user }

  describe 'GET /api/enrollment_payment_plans' do
    before do
      create_list(:enrollment_payment_plan, 3, program_enrollment: enrollment, payment_plan: payment_plan)
    end

    it 'returns all enrollment payment plans' do
      get '/api/enrollment_payment_plans'
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json.length).to eq(3)
    end
  end

  describe 'GET /api/enrollment_payment_plans/:id' do
    let(:enrollment_payment_plan) { create(:enrollment_payment_plan, program_enrollment: enrollment, payment_plan: payment_plan) }

    it 'returns the enrollment payment plan' do
      get "/api/enrollment_payment_plans/#{enrollment_payment_plan.id}"
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json['id']).to eq(enrollment_payment_plan.id)
    end
  end

  describe 'POST /api/enrollment_payment_plans' do
    it 'creates a new enrollment payment plan' do
      expect {
        post '/api/enrollment_payment_plans', params: {
          enrollment_payment_plan: {
            program_enrollment_id: enrollment.id,
            payment_plan_id: payment_plan.id,
            total_amount: 2800.00,
            enrollment_fee: 150.00
          }
        }
      }.to change(EnrollmentPaymentPlan, :count).by(1)

      expect(response).to have_http_status(:created)
    end
  end

  describe 'POST /api/enrollment_payment_plans/:id/record_enrollment_fee' do
    let(:enrollment_payment_plan) { create(:enrollment_payment_plan, program_enrollment: enrollment, payment_plan: payment_plan) }

    it 'records enrollment fee payment' do
      post "/api/enrollment_payment_plans/#{enrollment_payment_plan.id}/record_enrollment_fee", params: {
        payment_method: 'venmo',
        payment_date: Date.today.to_s,
        notes: 'Fee paid'
      }

      expect(response).to have_http_status(:success)
      enrollment_payment_plan.reload
      expect(enrollment_payment_plan.enrollment_fee_paid).to be true
    end
  end
end
