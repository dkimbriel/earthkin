require 'rails_helper'

RSpec.describe ReceiptPdfGenerator do
  let(:family) { create(:family) }
  let(:parent) { create(:parent, family: family, email: 'parent@example.com', phone: '(555) 123-4567') }
  let(:child) { create(:child, family: family) }
  let(:program) { create(:program) }
  let(:enrollment) { create(:program_enrollment, program: program, child: child) }

  before { parent } # Ensure parent exists

  describe '#generate' do
    context 'with completed tuition payment' do
      let(:payment) { create(:payment, program_enrollment: enrollment, amount: 280.00, status: 'completed', payment_type: 'tuition') }

      it 'generates a PDF receipt' do
        generator = ReceiptPdfGenerator.new(payment)
        pdf_content = generator.generate

        expect(pdf_content).to be_present
        expect(pdf_content).to be_a(String)
        expect(pdf_content.length).to be > 100
      end
    end

    context 'with enrollment fee receipt' do
      let(:payment) { create(:payment, :enrollment_fee, program_enrollment: enrollment, amount: 150.00, status: 'completed') }

      it 'includes enrollment fee description' do
        generator = ReceiptPdfGenerator.new(payment)
        pdf_content = generator.generate

        expect(pdf_content).to be_present
      end
    end

    context 'with installment payment' do
      let(:payment) { create(:payment, :with_payment_plan, program_enrollment: enrollment, amount: 280.00, installment_number: 5, payment_type: 'tuition', status: 'completed') }

      it 'includes installment information' do
        generator = ReceiptPdfGenerator.new(payment)
        pdf_content = generator.generate

        expect(pdf_content).to be_present
      end
    end

    context 'with payment notes' do
      let(:payment) { create(:payment, program_enrollment: enrollment, amount: 280.00, notes: 'Paid via check #1234', status: 'completed') }

      it 'includes notes in the PDF' do
        generator = ReceiptPdfGenerator.new(payment)
        pdf_content = generator.generate

        expect(pdf_content).to be_present
      end
    end

    context 'with payment plan' do
      let(:payment_plan) { create(:payment_plan, :monthly, program: program) }
      let(:enrollment_payment_plan) { create(:enrollment_payment_plan, :fee_paid, program_enrollment: enrollment, payment_plan: payment_plan, total_amount: 2800.00) }
      let(:payment) { create(:payment, :with_payment_plan, program_enrollment: enrollment, enrollment_payment_plan: enrollment_payment_plan, amount: 280.00, status: 'completed') }

      before { enrollment_payment_plan }

      it 'includes payment plan summary' do
        generator = ReceiptPdfGenerator.new(payment)
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
        generator = ReceiptPdfGenerator.new(payment)
        pdf_content = generator.generate

        expect(pdf_content).to be_present
      end
    end

    context 'with other payment type' do
      let(:payment) { create(:payment, program_enrollment: enrollment, amount: 50.00, status: 'completed', payment_type: 'other') }

      it 'shows generic payment description' do
        generator = ReceiptPdfGenerator.new(payment)
        pdf_content = generator.generate

        expect(pdf_content).to be_present
      end
    end
  end
end
