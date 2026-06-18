require 'rails_helper'

RSpec.describe PaymentPlan, type: :model do
  describe 'associations' do
    it { should belong_to(:program) }
    it { should have_many(:enrollment_payment_plans).dependent(:restrict_with_error) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:total_amount) }
    it { should validate_presence_of(:installment_count) }
  end

  describe 'scopes' do
    let(:program) { create(:program) }

    before do
      create(:payment_plan, program: program, active: true)
      create(:payment_plan, program: program, active: false)
    end

    it 'filters by active status' do
      expect(program.payment_plans.where(active: true).count).to eq(1)
      expect(program.payment_plans.where(active: false).count).to eq(1)
    end
  end

  describe 'installment calculation' do
    let(:payment_plan) { create(:payment_plan, :monthly) }

    it 'has correct installment schedule' do
      expect(payment_plan.installment_schedule.length).to eq(10)
      expect(payment_plan.installment_schedule.first['amount']).to eq(280)
    end

    it 'automatically calculates installment amount on save' do
      expect(payment_plan.installment_amount).to eq(280.0)
    end
  end
end
