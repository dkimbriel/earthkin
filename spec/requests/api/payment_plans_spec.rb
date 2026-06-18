require 'rails_helper'

RSpec.describe 'Api::PaymentPlans', type: :request do
  let(:user) { create(:user) }
  let(:program) { create(:program) }

  before do
    sign_in user
  end

  describe 'GET /api/payment_plans' do
    let!(:active_plans) { create_list(:payment_plan, 2, program: program, active: true) }
    let!(:inactive_plan) { create(:payment_plan, program: program, active: false) }

    it 'returns all payment plans' do
      get '/api/payment_plans'
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).length).to eq(3)
    end

    it 'filters by program_id' do
      other_program = create(:program)
      create(:payment_plan, program: other_program)

      get '/api/payment_plans', params: { program_id: program.id }
      expect(JSON.parse(response.body).length).to eq(3)
    end

    it 'filters by active status' do
      get '/api/payment_plans', params: { program_id: program.id, active: true }
      expect(JSON.parse(response.body).length).to eq(2)
    end

    it 'orders by display_order' do
      get '/api/payment_plans', params: { program_id: program.id }
      json = JSON.parse(response.body)
      expect(json.first['display_order']).to be <= json.last['display_order']
    end
  end

  describe 'POST /api/payment_plans' do
    let(:valid_params) do
      {
        payment_plan: {
          program_id: program.id,
          name: 'New Plan',
          description: 'Test plan',
          total_amount: 3000.00,
          installment_count: 2,
          installment_schedule: [
            { month: 8, day: 1, amount: 1500 },
            { month: 1, day: 1, amount: 1500 }
          ]
        }
      }
    end

    it 'creates a new payment plan' do
      expect {
        post '/api/payment_plans', params: valid_params
      }.to change(PaymentPlan, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['name']).to eq('New Plan')
    end
  end
end
