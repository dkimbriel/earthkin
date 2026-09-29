require 'rails_helper'

RSpec.describe StripeAutopay do
  let(:family) { create(:family, name: 'McLean') }
  let!(:parent) { create(:parent, family: family, email: 'mom@example.com') }
  let(:plan) { create(:enrollment_payment_plan, program_enrollment: create(:program_enrollment, child: create(:child, family: family))) }

  describe '.customer_id_for' do
    it "creates the family's Stripe customer once and reuses it" do
      expect(Stripe::Customer).to receive(:create).once
                                                  .with(hash_including(email: 'mom@example.com', metadata: { family_id: family.id }))
                                                  .and_return(double(id: 'cus_new'))

      expect(described_class.customer_id_for(family)).to eq('cus_new')
      expect(described_class.customer_id_for(family.reload)).to eq('cus_new')
    end
  end

  describe '.setup_session' do
    it 'saves a card or instantly verified bank account for this plan, without charging' do
      family.update!(stripe_customer_id: 'cus_1')
      expect(Stripe::Checkout::Session).to receive(:create).with(hash_including(
        mode: 'setup',
        customer: 'cus_1',
        payment_method_types: %w[card us_bank_account],
        payment_method_options: { us_bank_account: { verification_method: 'instant' } },
        metadata: { kind: 'autopay_setup', enrollment_payment_plan_id: plan.id, enabled_by: 'mom@example.com' }
      )).and_return(double(url: 'https://checkout.stripe.com/c/setup/1'))

      expect(described_class.setup_session(plan, parent_email: 'mom@example.com').url).to include('setup')
    end
  end

  describe '.method_details' do
    it 'labels cards and bank accounts' do
      card = double(id: 'pm_c', type: 'card', card: double(brand: 'mastercard', last4: '4444'))
      bank = double(id: 'pm_b', type: 'us_bank_account', us_bank_account: double(bank_name: 'Chase', last4: '6789'))

      expect(described_class.method_details(card)).to eq(id: 'pm_c', type: 'card', label: 'Mastercard ending 4444')
      expect(described_class.method_details(bank)).to eq(id: 'pm_b', type: 'us_bank_account', label: 'Chase ending 6789')
    end
  end
end
