require 'rails_helper'

RSpec.describe 'Api::Reports', type: :request do
  describe 'GET /api/reports/weekly_revenue' do
    it 'returns the weekly cash forecast' do
      sign_in create(:user)
      enrollment = create(:program_enrollment, status: 'confirmed')
      create(:enrollment_payment_plan, program_enrollment: enrollment,
                                       installments: [{ 'due_date' => Date.current.to_s, 'amount' => 280, 'status' => 'pending', 'paid_at' => nil }])

      get '/api/reports/weekly_revenue'

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json['weeks'].size).to eq(WeeklyCashForecast::WEEKS_BACK + WeeklyCashForecast::WEEKS_AHEAD)
      current = json['weeks'].find { |w| w['current'] }
      expect(current).to include('outstanding' => 280.0, 'collected' => 0)
      expect(json['totals']).to include('expected_upcoming' => 280.0, 'overdue' => 0)
    end

    it 'is admin-only, since it shows what each family has paid and owes' do
      sign_in create(:user, :teacher)
      get '/api/reports/weekly_revenue'
      expect(response).to have_http_status(:forbidden)
    end
  end
end
