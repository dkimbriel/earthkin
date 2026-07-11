require 'rails_helper'

RSpec.describe 'Api::Payments', type: :request do
  let(:user) { create(:user) }
  let(:enrollment) { create(:program_enrollment) }

  before do
    sign_in user
  end

  describe 'GET /api/payments' do
    let!(:payments) { create_list(:payment, 3, program_enrollment: enrollment) }

    it 'returns all payments' do
      get '/api/payments'
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).length).to eq(3)
    end
  end

  describe 'POST /api/payments' do
    let(:valid_params) do
      {
        payment: {
          program_enrollment_id: enrollment.id,
          amount: 280.00,
          payment_date: Date.today,
          payment_method: 'venmo',
          status: 'completed'
        }
      }
    end

    it 'creates a new payment' do
      expect {
        post '/api/payments', params: valid_params
      }.to change(Payment, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['amount']).to eq('280.0')
    end
  end

  describe 'POST /api/payments/:id/send_invoice' do
    let(:family) { create(:family) }
    let!(:parent) { create(:parent, family: family) }
    let(:child) { create(:child, family: family) }
    let(:enrollment) { create(:program_enrollment, child: child) }
    let(:payment) { create(:payment, program_enrollment: enrollment) }

    it 'sends receipt email for completed payment' do
      expect {
        post "/api/payments/#{payment.id}/send_invoice"
      }.to change { ActionMailer::Base.deliveries.count }.by(1)

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['message']).to eq('Receipt email sent successfully')

      email = payment.emails.order(:created_at).last
      expect(email.email_type).to eq('receipt')
      expect(email.status).to eq('sent')
    end
  end

  describe 'DELETE /api/payments/:id' do
    let!(:payment) { create(:payment, program_enrollment: enrollment) }

    it 'deletes the payment' do
      expect {
        delete "/api/payments/#{payment.id}"
      }.to change(Payment, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end
end
