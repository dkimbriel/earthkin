require 'rails_helper'

RSpec.describe PaymentDueReminder do
  let(:due_date) { Date.new(2026, 10, 1) }
  # Reminders go out LEAD_DAYS (3) before the due date.
  let(:run_date) { due_date - PaymentDueReminder::LEAD_DAYS }
  let(:family) { create(:family) }
  let!(:parent) { create(:parent, family: family, email: 'parent@example.com') }
  let(:child) { create(:child, family: family) }
  let(:program) { create(:program) }
  let(:enrollment) { create(:program_enrollment, child: child, program: program) }
  let(:payment_plan) { create(:payment_plan, :monthly, program: program) }

  let(:installments) do
    [
      { 'due_date' => '2026-09-01', 'amount' => 280, 'status' => 'completed', 'paid_at' => '2026-09-01' },
      { 'due_date' => '2026-10-01', 'amount' => 280, 'status' => 'pending', 'paid_at' => nil },
      { 'due_date' => '2026-11-01', 'amount' => 280, 'status' => 'pending', 'paid_at' => nil }
    ]
  end

  let!(:plan) do
    create(:enrollment_payment_plan, :fee_paid,
      program_enrollment: enrollment,
      payment_plan: payment_plan,
      installments: installments
    )
  end

  around do |example|
    ActionMailer::Base.deliveries.clear
    example.run
    ActionMailer::Base.deliveries.clear
  end

  describe '.run' do
    it 'emails parents three days before the installment is due' do
      expect { PaymentDueReminder.run(date: run_date) }
        .to change { ActionMailer::Base.deliveries.count }.by(1)

      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to eq(['parent@example.com'])
      expect(mail.subject).to include('Payment Due')
    end

    it 'creates a pending invoice for the due installment so it has a pay link' do
      expect { PaymentDueReminder.run(date: run_date) }
        .to change { plan.payments.where(installment_number: 2).count }.from(0).to(1)

      invoice = plan.payments.find_by(installment_number: 2)
      expect(invoice.status).to eq('pending')
      expect(invoice.amount).to eq(280)
      expect(invoice.payment_token).to be_present
    end

    it 'tracks the reminder as a payment_due email' do
      PaymentDueReminder.run(date: run_date)
      invoice = plan.payments.find_by(installment_number: 2)
      expect(invoice.emails.by_type('payment_due').sent.count).to eq(1)
    end

    it 'is idempotent — a second run does not re-email' do
      PaymentDueReminder.run(date: run_date)
      expect { PaymentDueReminder.run(date: run_date) }
        .not_to change { ActionMailer::Base.deliveries.count }
    end

    it 'returns the number of reminders sent' do
      expect(PaymentDueReminder.run(date: run_date)).to eq(1)
    end

    it 'sends nothing when no installment is due that day' do
      expect { PaymentDueReminder.run(date: Date.new(2026, 12, 25)) }
        .not_to change { ActionMailer::Base.deliveries.count }
    end

    it 'skips cancelled enrollments' do
      enrollment.update!(status: 'cancelled')
      expect { PaymentDueReminder.run(date: run_date) }
        .not_to change { ActionMailer::Base.deliveries.count }
    end
  end
end
