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

  describe '#generate_schedule' do
    let(:plan) { create(:payment_plan, :monthly, total_amount: 2800, installment_count: 10) }

    it 'splits the plan total evenly by default' do
      schedule = plan.generate_schedule('2026-08-24')

      expect(schedule.map { |i| i['amount'] }).to eq([280.0] * 10)
      expect(schedule.map { |i| i['due_date'] }.first(2)).to eq(%w[2026-08-24 2026-09-24])
    end

    it 'splits a custom total to the cent with the remainder on the first installment' do
      plan.update!(installment_count: 9)
      amounts = plan.generate_schedule('2026-09-24', total: 2460).map { |i| i['amount'] }

      expect(amounts).to eq([273.36] + [273.33] * 8)
      expect(amounts.sum { |a| BigDecimal(a.to_s) }).to eq(2460)
    end
  end
end
