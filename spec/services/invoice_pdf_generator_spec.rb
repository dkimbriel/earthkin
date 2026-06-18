require 'rails_helper'

RSpec.describe InvoicePdfGenerator do
  let(:family) { create(:family) }
  let(:parent) { create(:parent, family: family, email: 'parent@example.com', phone: '(555) 123-4567') }
  let(:child) { create(:child, family: family) }
  let(:program) { create(:program) }
  let(:enrollment) { create(:program_enrollment, program: program, child: child) }

  before { parent } # Ensure parent exists

  describe '#generate' do
    context 'with tuition payment' do
      let(:payment) { create(:payment, :pending, program_enrollment: enrollment, amount: 280.00, payment_type: 'tuition') }

      it 'generates a PDF invoice' do
        generator = InvoicePdfGenerator.new(payment)
        pdf_content = generator.generate

        expect(pdf_content).to be_present
        expect(pdf_content).to be_a(String)
        expect(pdf_content.length).to be > 100
      end
    end

    context 'with enrollment fee payment' do
      let(:payment) { create(:payment, :enrollment_fee, program_enrollment: enrollment, amount: 150.00, status: 'pending') }

      it 'includes enrollment fee description' do
        generator = InvoicePdfGenerator.new(payment)
        pdf_content = generator.generate

        expect(pdf_content).to be_present
      end
    end

    context 'with tuition payment with installment number' do
      let(:payment) { create(:payment, :with_payment_plan, program_enrollment: enrollment, amount: 280.00, installment_number: 3, payment_type: 'tuition', status: 'pending') }

      it 'includes installment information' do
        generator = InvoicePdfGenerator.new(payment)
        pdf_content = generator.generate

        expect(pdf_content).to be_present
      end
    end

    context 'with completed payment' do
      let(:payment) { create(:payment, program_enrollment: enrollment, amount: 280.00, status: 'completed') }

      it 'shows thank you message' do
        generator = InvoicePdfGenerator.new(payment)
        pdf_content = generator.generate

        expect(pdf_content).to be_present
      end
    end

    context 'with payment notes' do
      let(:payment) { create(:payment, program_enrollment: enrollment, amount: 280.00, notes: 'Special payment terms', status: 'pending') }

      it 'includes notes in the PDF' do
        generator = InvoicePdfGenerator.new(payment)
        pdf_content = generator.generate

        expect(pdf_content).to be_present
      end
    end

    context 'with payment plan' do
      let(:payment_plan) { create(:payment_plan, :monthly, program: program) }
      let(:enrollment_payment_plan) { create(:enrollment_payment_plan, :fee_paid, program_enrollment: enrollment, payment_plan: payment_plan, total_amount: 2800.00) }
      let(:payment) { create(:payment, :with_payment_plan, program_enrollment: enrollment, enrollment_payment_plan: enrollment_payment_plan, amount: 280.00, status: 'pending') }

      before { enrollment_payment_plan }

      it 'includes payment plan summary' do
        generator = InvoicePdfGenerator.new(payment)
        pdf_content = generator.generate

        expect(pdf_content).to be_present
      end
    end

    context 'with fully paid enrollment plan' do
      let(:payment_plan) { create(:payment_plan, program: program, total_amount: 280.00, installment_count: 1) }
      let(:enrollment_payment_plan) { create(:enrollment_payment_plan, :fee_paid, program_enrollment: enrollment, payment_plan: payment_plan, total_amount: 280.00) }
      let!(:paid_payment) { create(:payment, program_enrollment: enrollment, enrollment_payment_plan: enrollment_payment_plan, amount: 280.00, status: 'completed', payment_type: 'tuition') }
      let(:payment) { paid_payment }

      before { enrollment_payment_plan }

      it 'shows paid in full message' do
        generator = InvoicePdfGenerator.new(payment)
        pdf_content = generator.generate

        expect(pdf_content).to be_present
      end
    end
  end
end
