require 'rails_helper'

RSpec.describe EnrollmentPaymentPlan, type: :model do
  describe 'associations' do
    it { should belong_to(:program_enrollment) }
    it { should belong_to(:payment_plan) }
    it { should have_many(:payments).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:total_amount) }
    it { should validate_presence_of(:enrollment_fee) }
  end

  describe '#mark_enrollment_fee_paid!' do
    let(:enrollment_payment_plan) { create(:enrollment_payment_plan) }

    it 'marks enrollment fee as paid' do
      enrollment_payment_plan.mark_enrollment_fee_paid!
      expect(enrollment_payment_plan.enrollment_fee_paid).to be true
      expect(enrollment_payment_plan.enrollment_fee_paid_at).to be_present
    end
  end

  describe '#total_paid' do
    let(:enrollment_payment_plan) { create(:enrollment_payment_plan, :fee_paid) }

    it 'calculates total tuition paid (excluding enrollment fee)' do
      create(:payment, :enrollment_fee, enrollment_payment_plan: enrollment_payment_plan, amount: 150)
      create(:payment, :with_payment_plan, enrollment_payment_plan: enrollment_payment_plan, amount: 280, payment_type: 'tuition')

      expect(enrollment_payment_plan.tuition_paid).to eq(280.0)
    end
  end

  describe '#next_installment' do
    let(:enrollment_payment_plan) do
      create(:enrollment_payment_plan, :with_monthly_plan, :fee_paid)
    end

    it 'returns the next pending installment' do
      next_inst = enrollment_payment_plan.next_installment
      expect(next_inst).to be_present
      expect(next_inst['status']).to eq('pending')
    end

    it 'returns nil when all installments are paid' do
      enrollment_payment_plan.installments.each do |inst|
        inst['status'] = 'paid'
      end
      enrollment_payment_plan.save!

      expect(enrollment_payment_plan.next_installment).to be_nil
    end
  end

  describe '#overdue_installments' do
    let(:enrollment_payment_plan) do
      plan = create(:enrollment_payment_plan, :with_monthly_plan)
      plan.installments.first['due_date'] = 1.month.ago.to_date.to_s
      plan.save!
      plan
    end

    it 'returns overdue installments' do
      overdue = enrollment_payment_plan.overdue_installments
      expect(overdue.length).to be > 0
      expect(Date.parse(overdue.first['due_date'])).to be < Date.today
    end
  end
end
