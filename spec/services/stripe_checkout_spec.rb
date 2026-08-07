require 'rails_helper'

RSpec.describe StripeCheckout do
  let(:program) { create(:program, start_date: '2026-09-01') }
  let!(:plan) { create(:payment_plan, program: program, installment_count: 1, total_amount: 2800) }

  describe '.enrollment_fee_session' do
    let(:application) do
      create(:enrollment_application, program: program, status: 'fee_requested',
                                      custom_enrollment_fee: 200, payment_selection_token: 'tok-1')
    end

    it 'creates a fee session for the exact fee with provisioning metadata' do
      expect(Stripe::Checkout::Session).to receive(:create) do |args|
        expect(args[:mode]).to eq('payment')
        expect(args[:line_items].first[:price_data][:unit_amount]).to eq(20_000) # $200 in cents
        expect(args[:metadata]).to include(kind: 'enrollment_fee', payment_plan_id: plan.id)
        double(url: 'https://checkout')
      end

      described_class.enrollment_fee_session(application, plan)
    end
  end

  describe '.installment_session' do
    let(:eplan) { create(:enrollment_payment_plan, :with_monthly_plan) }

    it 'creates a session for the installment amount with installment metadata' do
      expect(Stripe::Checkout::Session).to receive(:create) do |args|
        expect(args[:line_items].first[:price_data][:unit_amount]).to eq(28_000) # $280
        expect(args[:metadata]).to include(kind: 'installment', installment_index: 0)
        double(url: 'https://checkout')
      end

      described_class.installment_session(eplan, 0)
    end

    it 'raises for an out-of-range installment' do
      expect { described_class.installment_session(eplan, 99) }.to raise_error(ArgumentError)
    end
  end
end
