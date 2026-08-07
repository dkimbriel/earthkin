require 'rails_helper'

RSpec.describe 'Webhooks::Stripe', type: :request do
  # A fake checkout.session.completed event. metadata is a plain Hash (string
  # keys), matching how the controller reads Stripe's StripeObject via [].
  def checkout_event(session_id:, payment_intent: 'pi_test_1', metadata: {})
    session = double('Stripe::Checkout::Session',
                     id: session_id, payment_intent: payment_intent, metadata: metadata)
    double('Stripe::Event', type: 'checkout.session.completed',
                            data: double('data', object: session))
  end

  before do
    # Every test drives a specific event through the (stubbed) signature check.
    allow(Stripe::PaymentIntent).to receive(:retrieve).and_return(
      double('intent', latest_charge: double('charge', receipt_url: 'https://pay.stripe.com/receipts/abc'))
    )
  end

  def post_webhook
    post '/webhooks/stripe', headers: { 'HTTP_STRIPE_SIGNATURE' => 'sig_test' }
  end

  describe 'signature verification' do
    it 'rejects an event with a bad signature' do
      allow(Stripe::Webhook).to receive(:construct_event)
        .and_raise(Stripe::SignatureVerificationError.new('bad', 'sig'))

      post_webhook
      expect(response).to have_http_status(:bad_request)
    end
  end

  describe 'enrollment fee completed' do
    let(:program) { create(:program, start_date: '2026-09-01') }
    let!(:plan) { create(:payment_plan, program: program, installment_count: 1, total_amount: 2800) }
    let(:application) { create(:enrollment_application, :meeting_completed, program: program) }

    let(:event) do
      checkout_event(session_id: 'cs_fee_1', metadata: {
        'kind' => 'enrollment_fee',
        'application_id' => application.id,
        'payment_plan_id' => plan.id
      })
    end

    before { allow(Stripe::Webhook).to receive(:construct_event).and_return(event) }

    it 'provisions the enrollment and records a stripe payment' do
      expect { post_webhook }.to change(Payment, :count).by(1)

      expect(response).to have_http_status(:ok)
      application.reload
      expect(application.status).to eq('fee_paid')

      payment = Payment.last
      expect(payment.payment_method).to eq('stripe')
      expect(payment.payment_type).to eq('enrollment_fee')
      expect(payment.stripe_checkout_session_id).to eq('cs_fee_1')
      expect(payment.stripe_receipt_url).to eq('https://pay.stripe.com/receipts/abc')
    end

    it 'is idempotent when Stripe replays the event' do
      post_webhook
      expect { post_webhook }.not_to change(Payment, :count)
    end
  end

  describe 'installment completed' do
    let(:plan) { create(:enrollment_payment_plan, :with_monthly_plan) }

    let(:event) do
      checkout_event(session_id: 'cs_inst_1', metadata: {
        'kind' => 'installment',
        'enrollment_payment_plan_id' => plan.id,
        'installment_index' => 0
      })
    end

    before { allow(Stripe::Webhook).to receive(:construct_event).and_return(event) }

    it 'records the tuition payment and marks the installment paid' do
      expect { post_webhook }.to change(Payment, :count).by(1)

      expect(response).to have_http_status(:ok)
      payment = Payment.last
      expect(payment.payment_type).to eq('tuition')
      expect(payment.payment_method).to eq('stripe')
      expect(plan.reload.installments[0]['status']).to eq('completed')
    end

    it 'does not double-charge a replayed event' do
      post_webhook
      expect { post_webhook }.not_to change(Payment, :count)
    end
  end

  describe 'invoice completed' do
    let(:plan) { create(:enrollment_payment_plan, :with_monthly_plan) }
    let(:payment) do
      create(:payment, :pending, program_enrollment: plan.program_enrollment,
                                 enrollment_payment_plan: plan, payment_type: 'tuition',
                                 amount: 280, installment_number: 1)
    end

    let(:event) do
      checkout_event(session_id: 'cs_invoice_1', metadata: {
        'kind' => 'invoice', 'payment_id' => payment.id
      })
    end

    before { allow(Stripe::Webhook).to receive(:construct_event).and_return(event) }

    it 'marks the pending payment completed with stripe details and flips the installment' do
      expect { post_webhook }.not_to change(Payment, :count) # updates, not creates

      expect(response).to have_http_status(:ok)
      payment.reload
      expect(payment.status).to eq('completed')
      expect(payment.payment_method).to eq('stripe')
      expect(payment.stripe_checkout_session_id).to eq('cs_invoice_1')
      expect(plan.reload.installments[0]['status']).to eq('completed')
    end

    it 'is idempotent on replay' do
      post_webhook
      expect { post_webhook }.not_to(change { payment.reload.stripe_payment_intent_id })
    end
  end
end
