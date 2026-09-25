require 'rails_helper'

RSpec.describe 'Api::EnrollmentPaymentPlans', type: :request do
  let(:user) { create(:user) }
  let(:program) { create(:program) }
  let(:payment_plan) { create(:payment_plan, program: program) }
  let(:enrollment) { create(:program_enrollment, program: program) }

  before { sign_in user }

  describe 'GET /api/enrollment_payment_plans' do
    before do
      3.times do
        enr = create(:program_enrollment, program: program)
        create(:enrollment_payment_plan, program_enrollment: enr, payment_plan: payment_plan)
      end
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

    it 'anchors installment due dates to the program start date' do
      program.update!(start_date: Date.new(2026, 8, 24))
      payment_plan.update!(installment_count: 3, total_amount: 3000)

      post '/api/enrollment_payment_plans', params: {
        enrollment_payment_plan: {
          program_enrollment_id: enrollment.id,
          payment_plan_id: payment_plan.id,
          enrollment_fee: 0
        }
      }

      expect(response).to have_http_status(:created)
      plan = EnrollmentPaymentPlan.last
      expect(plan.installments.map { |i| i['due_date'] }).to eq(%w[2026-08-24 2026-09-24 2026-10-24])
      expect(plan.installments).to all(include('status' => 'pending'))
      expect(plan.total_amount).to eq(payment_plan.reload.total_amount)
    end

    it 'honors an explicit start date override' do
      payment_plan.update!(installment_count: 2)

      post '/api/enrollment_payment_plans', params: {
        enrollment_payment_plan: {
          program_enrollment_id: enrollment.id,
          payment_plan_id: payment_plan.id,
          enrollment_fee: 0,
          start_date: '2026-09-01'
        }
      }

      plan = EnrollmentPaymentPlan.last
      expect(plan.installments.map { |i| i['due_date'] }).to eq(%w[2026-09-01 2026-10-01])
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

  describe 'POST /api/enrollment_payment_plans with a custom total' do
    it 'splits the custom total instead of the template amount' do
      monthly = create(:payment_plan, :monthly, program: program)

      post '/api/enrollment_payment_plans', params: {
        enrollment_payment_plan: { program_enrollment_id: enrollment.id, payment_plan_id: monthly.id, total_amount: 2460 }
      }

      amounts = EnrollmentPaymentPlan.last.installments.map { |i| BigDecimal(i['amount'].to_s) }
      expect(amounts.sum).to eq(2460)
    end
  end

  describe 'PATCH /api/enrollment_payment_plans/:id' do
    let(:plan) { create(:enrollment_payment_plan, :with_monthly_plan, program_enrollment: enrollment) }
    let(:rows) do
      [{ due_date: '2026-09-28', amount: '1230.00', original_index: 0 },
       { due_date: '2026-10-24', amount: '1230.00' }]
    end

    it 'saves an edited schedule for an admin' do
      patch "/api/enrollment_payment_plans/#{plan.id}", params: {
        enrollment_payment_plan: { total_amount: '2460', installments: rows }
      }

      expect(response).to have_http_status(:success)
      expect(plan.reload.installments.map { |i| i['due_date'] }).to eq(%w[2026-09-28 2026-10-24])
      expect(plan.total_amount).to eq(2460)
    end

    it 'returns the reason when the schedule is invalid' do
      patch "/api/enrollment_payment_plans/#{plan.id}", params: {
        enrollment_payment_plan: { total_amount: '2800', installments: rows }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to match(/add up to/)
    end

    context 'as a teacher' do
      let(:user) { create(:user, :teacher) }

      it 'is forbidden' do
        patch "/api/enrollment_payment_plans/#{plan.id}", params: {
          enrollment_payment_plan: { total_amount: '2460', installments: rows }
        }

        expect(response).to have_http_status(:forbidden)
        expect(plan.reload.installments.size).to eq(10)
      end
    end
  end
end
