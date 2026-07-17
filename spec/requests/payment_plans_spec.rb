require 'rails_helper'

RSpec.describe 'Api::PaymentPlans', type: :request do
  let(:user) { create(:user) }
  let(:program) { create(:program) }

  before { sign_in user }

  describe 'GET /api/payment_plans' do
    before do
      create_list(:payment_plan, 3, program: program)
      create(:payment_plan, program: program, active: false)
    end

    it 'returns all payment plans' do
      get '/api/payment_plans'
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json.length).to eq(4)
    end

    it 'filters by program_id' do
      other_program = create(:program)
      create(:payment_plan, program: other_program)

      get '/api/payment_plans', params: { program_id: program.id }
      json = JSON.parse(response.body)
      expect(json.length).to eq(4)
    end

    it 'filters by active status' do
      get '/api/payment_plans', params: { active: 'true' }
      json = JSON.parse(response.body)
      expect(json.length).to eq(3)
    end

    it 'includes program data' do
      get '/api/payment_plans'
      json = JSON.parse(response.body)
      expect(json.first).to have_key('program')
    end
  end

  describe 'GET /api/payment_plans/:id' do
    let(:payment_plan) { create(:payment_plan, program: program) }

    it 'returns the payment plan' do
      get "/api/payment_plans/#{payment_plan.id}"
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json['id']).to eq(payment_plan.id)
    end
  end

  describe 'POST /api/payment_plans' do
    let(:valid_params) do
      {
        payment_plan: {
          program_id: program.id,
          name: 'Custom Plan',
          description: 'A custom payment plan',
          installment_count: 3,
          total_amount: 1500.00,
          display_order: 5
        }
      }
    end

    it 'creates a new payment plan' do
      expect {
        post '/api/payment_plans', params: valid_params
      }.to change(PaymentPlan, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['name']).to eq('Custom Plan')
      expect(json['installment_amount'].to_f).to eq(500.0)
    end
  end

  describe 'PATCH /api/payment_plans/:id' do
    let(:payment_plan) { create(:payment_plan, program: program) }

    it 'updates the payment plan' do
      patch "/api/payment_plans/#{payment_plan.id}", params: {
        payment_plan: { name: 'Updated Plan Name' }
      }

      expect(response).to have_http_status(:success)
      expect(payment_plan.reload.name).to eq('Updated Plan Name')
    end
  end

  describe 'DELETE /api/payment_plans/:id' do
    let(:payment_plan) { create(:payment_plan, program: program) }

    it 'destroys the payment plan' do
      payment_plan # create it first

      expect {
        delete "/api/payment_plans/#{payment_plan.id}"
      }.to change(PaymentPlan, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it 'prevents deletion if enrollments exist' do
      create(:enrollment_payment_plan, payment_plan: payment_plan)

      expect {
        delete "/api/payment_plans/#{payment_plan.id}"
      }.not_to change(PaymentPlan, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
