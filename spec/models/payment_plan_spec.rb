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

  describe '.split_amount' do
    it 'puts the rounding remainder on the last payment so the total is exact' do
      amounts = described_class.split_amount(2500, 9)
      expect(amounts.first(8)).to all(eq(277.78))
      expect(amounts.last).to eq(277.76)
      expect(amounts.sum).to eq(2500)
    end
  end

  describe '#generate_schedule' do
    let(:payment_plan) { create(:payment_plan, :monthly) }

    it 'uses the standard installment amount by default' do
      expect(payment_plan.generate_schedule('2026-08-01').map { |i| i['amount'] }).to all(eq(280.0))
    end

    it 'bills from a custom total when given one' do
      schedule = payment_plan.generate_schedule('2026-08-01', total_amount: 2500)
      expect(schedule.map { |i| i['amount'] }).to all(eq(250.0))
      expect(schedule.map { |i| i['due_date'] }.first(2)).to eq(%w[2026-08-01 2026-09-01])
    end
  end
end
