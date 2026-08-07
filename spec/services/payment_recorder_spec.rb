require 'rails_helper'

RSpec.describe PaymentRecorder do
  describe '.record_installment' do
    let(:plan) { create(:enrollment_payment_plan, :with_monthly_plan) }

    it 'creates a tuition payment and marks the installment paid' do
      payment = described_class.record_installment(
        plan, installment_index: 0, amount: 280, payment_method: 'check'
      )

      expect(payment).to be_persisted
      expect(payment.payment_type).to eq('tuition')
      expect(payment.installment_number).to eq(1)
      expect(plan.reload.installments[0]['status']).to eq('completed')
    end

    it 'attaches stripe identifiers when provided' do
      payment = described_class.record_installment(
        plan, installment_index: 1, amount: 280, payment_method: 'stripe',
        stripe: { session_id: 'cs_1', payment_intent_id: 'pi_1', receipt_url: 'https://r' }
      )

      expect(payment.stripe_checkout_session_id).to eq('cs_1')
      expect(payment.stripe_receipt_url).to eq('https://r')
    end
  end

  describe '.stripe_attrs' do
    it 'maps present keys and drops blanks' do
      expect(described_class.stripe_attrs(session_id: 'cs', receipt_url: nil))
        .to eq(stripe_checkout_session_id: 'cs')
    end

    it 'returns an empty hash for blank input' do
      expect(described_class.stripe_attrs({})).to eq({})
    end
  end
end
