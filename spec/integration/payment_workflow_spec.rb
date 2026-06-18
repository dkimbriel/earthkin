require 'rails_helper'

RSpec.describe 'Payment Workflow', type: :request do
  let(:user) { create(:user) }
  let(:family) { create(:family) }
  let(:parent) { create(:parent, family: family, email: 'parent@example.com') }
  let(:child) { create(:child, family: family) }
  let(:program) { create(:program) }
  let(:payment_plan) { create(:payment_plan, :monthly, program: program) }
  let(:enrollment) { create(:program_enrollment, program: program, child: child) }

  before do
    sign_in user
    parent
    allow(PaymentMailer).to receive_message_chain(:invoice, :deliver_later)
    allow(PaymentMailer).to receive_message_chain(:receipt, :deliver_later)
  end

  it 'manages complete payment workflow' do
    # Step 1: Create enrollment payment plan
    post '/api/enrollment_payment_plans', params: {
      enrollment_payment_plan: {
        program_enrollment_id: enrollment.id,
        payment_plan_id: payment_plan.id,
        total_amount: 2800.00,
        enrollment_fee: 150.00
      }
    }
    expect(response).to have_http_status(:created)
    plan_data = JSON.parse(response.body)
    plan_id = plan_data['id']

    # Step 2: Record enrollment fee
    post "/api/enrollment_payment_plans/#{plan_id}/record_enrollment_fee", params: {
      payment_method: 'venmo',
      payment_date: Date.today.to_s,
      notes: 'Venmo payment received'
    }
    expect(response).to have_http_status(:success)

    # Step 3: Verify enrollment fee was marked as paid
    get "/api/enrollment_payment_plans/#{plan_id}"
    expect(response).to have_http_status(:success)
    plan = JSON.parse(response.body)
    expect(plan['enrollment_fee_paid']).to be true

    # Step 4: Record first tuition payment
    post '/api/payments', params: {
      payment: {
        program_enrollment_id: enrollment.id,
        amount: 280.00,
        payment_date: Date.today.to_s,
        payment_method: 'venmo',
        status: 'completed',
        payment_type: 'tuition'
      }
    }
    expect(response).to have_http_status(:created)
    payment1_data = JSON.parse(response.body)
    payment1_id = payment1_data['id']

    # Step 5: Record second tuition payment
    post '/api/payments', params: {
      payment: {
        program_enrollment_id: enrollment.id,
        amount: 280.00,
        payment_date: 1.month.from_now.to_date.to_s,
        payment_method: 'check',
        status: 'pending',
        payment_type: 'tuition',
        notes: 'Check #1234'
      }
    }
    expect(response).to have_http_status(:created)
    payment2_data = JSON.parse(response.body)
    payment2_id = payment2_data['id']

    # Step 6: View all payments for this enrollment
    get '/api/payments', params: { program_enrollment_id: enrollment.id }
    expect(response).to have_http_status(:success)
    payments = JSON.parse(response.body)
    expect(payments.length).to be >= 3 # Enrollment fee + 2 tuition payments

    # Step 7: Send invoice for pending payment
    post "/api/payments/#{payment2_id}/send_invoice"
    expect(response).to have_http_status(:ok)
    result = JSON.parse(response.body)
    expect(result['message']).to include('Invoice')

    # Step 8: Send receipt for completed payment
    post "/api/payments/#{payment1_id}/send_invoice"
    expect(response).to have_http_status(:ok)
    result = JSON.parse(response.body)
    expect(result['message']).to include('Receipt')

    # Step 9: View specific payment
    get "/api/payments/#{payment1_id}"
    expect(response).to have_http_status(:success)
    payment = JSON.parse(response.body)
    expect(payment['amount']).to eq('280.0')
    expect(payment['status']).to eq('completed')

    # Step 10: Filter payments by type
    enrollment_fee_payments = Payment.where(program_enrollment: enrollment, payment_type: 'enrollment_fee')
    expect(enrollment_fee_payments.count).to eq(1)

    tuition_payments = Payment.where(program_enrollment: enrollment, payment_type: 'tuition')
    expect(tuition_payments.count).to eq(2)

    # Step 11: Delete a payment
    delete "/api/payments/#{payment2_id}"
    expect(response).to have_http_status(:no_content)

    get '/api/payments', params: { program_enrollment_id: enrollment.id }
    payments = JSON.parse(response.body)
    expect(payments.none? { |p| p['id'] == payment2_id }).to be true
  end

  it 'handles payment plan with installments' do
    # Create enrollment with payment plan
    post '/api/enrollment_payment_plans', params: {
      enrollment_payment_plan: {
        program_enrollment_id: enrollment.id,
        payment_plan_id: payment_plan.id,
        total_amount: 2800.00,
        enrollment_fee: 150.00
      }
    }
    plan_id = JSON.parse(response.body)['id']

    # Record multiple installment payments
    10.times do |i|
      post '/api/payments', params: {
        payment: {
          program_enrollment_id: enrollment.id,
          amount: 280.00,
          payment_date: (i + 1).months.from_now.to_date.to_s,
          payment_method: 'venmo',
          status: 'completed',
          payment_type: 'tuition',
          installment_number: i + 1
        }
      }
      expect(response).to have_http_status(:created)
    end

    # Verify all payments recorded
    get '/api/payments', params: { program_enrollment_id: enrollment.id }
    payments = JSON.parse(response.body)
    tuition_payments = payments.select { |p| p['payment_type'] == 'tuition' }
    expect(tuition_payments.length).to eq(10)
  end
end
