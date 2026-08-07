require 'rails_helper'

RSpec.describe PaymentMailer, type: :mailer do
  describe 'invoice' do
    let(:family) { create(:family) }
    let!(:parent) { create(:parent, family: family, email: 'parent@example.com') }
    let(:child) { create(:child, family: family) }
    let(:program) { create(:program) }
    let(:enrollment) { create(:program_enrollment, child: child, program: program) }
    let(:payment) { create(:payment, :pending, program_enrollment: enrollment, amount: 150.00) }
    let(:mail) { PaymentMailer.invoice(payment.id) }

    it 'renders the headers' do
      expect(mail.subject).to include('Payment Invoice')
      expect(mail.subject).to include(child.first_name)
      expect(mail.to).to eq(['parent@example.com'])
    end

    it 'renders the body' do
      expect(mail.body.encoded).to include(child.first_name)
      expect(mail.body.encoded).to include(program.name)
      expect(mail.body.encoded).to include('$150.00')
    end

    it 'includes a Stripe pay link instead of a PDF attachment' do
      expect(mail.attachments.map(&:filename)).not_to include(a_string_matching(/\.pdf/i))
      expect(mail.body.encoded).to include("/pay/#{payment.reload.payment_token}")
      expect(mail.body.encoded).to match(/Pay .*Securely/)
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
