require 'rails_helper'

RSpec.describe 'Webhooks::Stripe autopay', type: :request do
  let(:family) { create(:family, stripe_customer_id: 'cus_1') }
  let(:child) { create(:child, family: family) }
  let(:enrollment) { create(:program_enrollment, child: child) }
  let(:plan) do
    create(:enrollment_payment_plan, program_enrollment: enrollment,
                                     installments: [{ 'due_date' => '2026-10-24', 'amount' => 280, 'status' => 'pending', 'paid_at' => nil }])
  end

  def post_event(type, object)
    event = double('Stripe::Event', type: type, data: double('data', object: object))
    allow(Stripe::Webhook).to receive(:construct_event).and_return(event)
    post '/webhooks/stripe', headers: { 'HTTP_STRIPE_SIGNATURE' => 'sig_test' }
  end

  describe 'setup session completed' do
    let(:card) do
      double('Stripe::PaymentMethod', id: 'pm_1', type: 'card', card: double(brand: 'visa', last4: '4242'))
    end

    def session(customer: 'cus_1')
      double('Stripe::Checkout::Session', id: 'cs_setup', customer: customer, setup_intent: 'seti_1',
                                          metadata: { 'kind' => 'autopay_setup', 'enrollment_payment_plan_id' => plan.id,
                                                      'enabled_by' => 'mom@example.com' })
    end

    before do
      allow(Stripe::SetupIntent).to receive(:retrieve)
        .and_return(double('Stripe::SetupIntent', status: 'succeeded', payment_method: card, mandate: nil))
    end

    it 'turns autopay on with the saved method and records the consent' do
      post_event('checkout.session.completed', session)

      expect(response).to have_http_status(:ok)
      expect(plan.reload).to have_attributes(autopay_payment_method_id: 'pm_1', autopay_method_type: 'card',
                                             autopay_method_label: 'Visa ending 4242', autopay_enabled_by: 'mom@example.com')
      expect(plan.autopay_consent_text).to include('I authorize Earthkin Nature School')
    end

    it "ignores a session whose customer isn't the plan's family" do
      post_event('checkout.session.completed', session(customer: 'cus_someone_else'))
      expect(plan.reload).not_to be_autopay
    end
  end

  describe 'autopay payment intents' do
    let(:invoice) do
      create(:payment, program_enrollment: enrollment, enrollment_payment_plan: plan, status: 'pending', amount: 280,
                       payment_date: '2026-10-24', installment_number: 1, autopay_attempts: 1,
                       stripe_payment_intent_id: 'pi_bank')
    end

    def intent(id: 'pi_bank', error: nil)
      double('Stripe::PaymentIntent', id: id, metadata: { 'kind' => 'autopay', 'payment_id' => invoice.id },
                                      last_payment_error: error && double(message: error))
    end

    before do
      allow(Stripe::PaymentIntent).to receive(:retrieve)
        .and_return(double(latest_charge: double(receipt_url: 'https://pay.stripe.com/r/2')))
      allow(AdminNotifier).to receive(:payment_completed)
    end

    it 'settles a bank payment when it succeeds' do
      post_event('payment_intent.succeeded', intent)

      expect(invoice.reload).to have_attributes(status: 'completed', stripe_receipt_url: 'https://pay.stripe.com/r/2')
      expect(plan.reload.installments.first['status']).to eq('completed')
      expect(AdminNotifier).to have_received(:payment_completed)
    end

    it 'schedules a retry when a processing bank payment fails' do
      post_event('payment_intent.payment_failed', intent(error: 'Insufficient funds'))

      expect(invoice.reload).to have_attributes(status: 'pending', autopay_error: 'Insufficient funds',
                                                autopay_retry_on: Date.current + 3, stripe_payment_intent_id: nil)
    end

    it 'ignores a failure for an intent that is no longer in flight (card declines are handled inline)' do
      invoice.update!(stripe_payment_intent_id: nil, autopay_error: 'Declined', autopay_retry_on: Date.current + 3)

      post_event('payment_intent.payment_failed', intent(id: 'pi_card', error: 'Declined'))

      expect(invoice.reload.autopay_attempts).to eq(1)
    end

    it 'ignores payment intents that are not autopay' do
      other = double('Stripe::PaymentIntent', id: 'pi_x', metadata: {}, last_payment_error: nil)
      post_event('payment_intent.succeeded', other)

      expect(response).to have_http_status(:ok)
      expect(invoice.reload.status).to eq('pending')
    end
  end
end
