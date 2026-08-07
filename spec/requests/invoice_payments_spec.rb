require 'rails_helper'

RSpec.describe 'InvoicePayments', type: :request do
  let(:enrollment) { create(:program_enrollment) }
  let(:payment) do
    create(:payment, :pending, program_enrollment: enrollment, amount: 280, payment_type: 'tuition')
  end

  describe 'GET /pay/:token' do
    it 'shows the amount and a pay button for an unpaid invoice' do
      get "/pay/#{payment.pay_token!}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('$280.00')
      expect(response.body).to match(/Pay .*\$280\.00/)
    end

    it 'shows a paid state once completed' do
      payment.update!(status: 'completed', payment_token: 'tok-paid')

      get '/pay/tok-paid'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Payment Received')
    end

    it '404s for an unknown token' do
      get '/pay/nope'
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /pay/:token' do
    it 'creates a Checkout Session and redirects to Stripe' do
      expect(StripeCheckout).to receive(:invoice_session)
        .with(an_instance_of(Payment))
        .and_return(double(url: 'https://checkout.stripe.com/c/pay/cs_1'))

      post "/pay/#{payment.pay_token!}"

      expect(response).to redirect_to('https://checkout.stripe.com/c/pay/cs_1')
    end

    it 'redirects back to the paid page if already completed' do
      payment.update!(status: 'completed')

      post "/pay/#{payment.pay_token!}"

      expect(response).to redirect_to(invoice_payment_path(payment.payment_token))
    end
  end
end
