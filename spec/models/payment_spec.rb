require 'rails_helper'

RSpec.describe Payment, type: :model do
  describe 'associations' do
    it { should belong_to(:program_enrollment) }
    it { should belong_to(:enrollment_payment_plan).optional }
  end

  describe 'validations' do
    it { should validate_presence_of(:amount) }
    it { should validate_presence_of(:payment_date) }
    it { should validate_presence_of(:status) }
    it do
      should validate_inclusion_of(:payment_type).in_array(
        %w[enrollment_fee tuition other]
      )
    end
  end

  describe 'scopes' do
    let(:enrollment) { create(:program_enrollment) }

    before do
      create(:payment, :enrollment_fee, program_enrollment: enrollment)
      create(:payment, program_enrollment: enrollment, payment_type: 'tuition')
    end

    it 'filters by payment type' do
      expect(Payment.enrollment_fees.count).to eq(1)
      expect(Payment.tuition_payments.count).to eq(1)
    end
  end

  describe 'factory' do
    it 'has a valid factory' do
      expect(build(:payment)).to be_valid
    end

    it 'creates an enrollment fee payment' do
      payment = create(:payment, :enrollment_fee)
      expect(payment.payment_type).to eq('enrollment_fee')
      expect(payment.amount).to eq(150.0)
    end

    it 'creates a payment with payment plan' do
      payment = create(:payment, :with_payment_plan)
      expect(payment.enrollment_payment_plan).to be_present
      expect(payment.installment_number).to eq(1)
    end
  end
end
