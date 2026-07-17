require 'rails_helper'

RSpec.describe PaymentMailer, type: :mailer do
  describe 'invoice' do
    let(:family) { create(:family) }
    let!(:parent) { create(:parent, family: family, email: 'parent@example.com') }
    let(:child) { create(:child, family: family) }
    let(:program) { create(:program) }
    let(:enrollment) { create(:program_enrollment, child: child, program: program) }
    let(:payment) { create(:payment, program_enrollment: enrollment, amount: 150.00) }
    let(:mail) { PaymentMailer.invoice(payment.id) }

    before do
      allow_any_instance_of(InvoicePdfGenerator).to receive(:generate).and_return('PDF_CONTENT')
    end

    it 'renders the headers' do
      expect(mail.subject).to include('Payment Invoice')
      expect(mail.subject).to include(child.first_name)
      expect(mail.to).to eq(['parent@example.com'])
    end

    it 'renders the body' do
      expect(mail.body.encoded).to include('Please find attached the invoice')
      expect(mail.body.encoded).to include(child.first_name)
      expect(mail.body.encoded).to include(program.name)
      expect(mail.body.encoded).to include('$150.00')
    end

    it 'attaches PDF invoice' do
      pdf = mail.attachments.find { |a| a.filename =~ /Invoice_.*\.pdf/ }
      expect(pdf).to be_present
      expect(pdf.content_type).to include('application/pdf')
    end

    context 'with payment plan' do
      let(:payment_plan) { create(:payment_plan, program: program) }
      let(:enrollment_payment_plan) do
        create(:enrollment_payment_plan,
          program_enrollment: enrollment,
          payment_plan: payment_plan,
          enrollment_fee_paid: true
        )
      end
      let(:payment) do
        create(:payment,
          program_enrollment: enrollment,
          enrollment_payment_plan: enrollment_payment_plan,
          payment_type: 'tuition',
          amount: 280.00
        )
      end

      it 'includes payment plan status' do
        expect(mail.body.encoded).to include('Payment Plan Status')
        expect(mail.body.encoded).to include(payment_plan.name)
        expect(mail.body.encoded).to include('$2,800.00')
      end
    end
  end
end
