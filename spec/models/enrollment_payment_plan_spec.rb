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

  describe '#change_plan!' do
    let(:plan) { create(:enrollment_payment_plan) }
    let(:monthly) { create(:payment_plan, :monthly, program: plan.payment_plan.program) }

    it 'splits the tuition override across the new plan instead of using template amounts' do
      plan.change_plan!(monthly, tuition_override: BigDecimal('2461.03'))

      amounts = plan.reload.installments.map { |i| i['amount'] }
      expect(plan.total_amount).to eq(BigDecimal('2461.03'))
      expect(amounts).to eq([246.13] + [246.10] * 9)
    end
  end

  describe '#update_schedule!' do
    let(:application) { create(:enrollment_application) }
    let(:enrollment) { create(:program_enrollment, enrollment_application: application) }
    let(:plan) do
      create(:enrollment_payment_plan, :with_monthly_plan, program_enrollment: enrollment,
             installments: (0..9).map { |i| { due_date: (Date.new(2026, 8, 24) >> i).to_s, amount: 280, status: 'pending', paid_at: nil } })
    end

    # A prorated mid-year start: first payment on the start date, then the 24th.
    let(:prorated_rows) do
      [{ due_date: '2026-09-28', amount: '273.36', original_index: 0 }] +
        (1..8).map { |i| { due_date: (Date.new(2026, 10, 24) >> (i - 1)).to_s, amount: '273.33', original_index: i } }
    end

    def keep_row(index, overrides = {})
      original = plan.installments[index]
      { due_date: original['due_date'], amount: original['amount'].to_s, original_index: index }.merge(overrides)
    end

    it 'replaces the total and schedule, dropping an installment' do
      plan.update_schedule!(total_amount: '2460', rows: prorated_rows)
      plan.reload

      expect(plan.total_amount).to eq(2460)
      expect(plan.installments.size).to eq(9)
      expect(plan.installments.first).to include('due_date' => '2026-09-28', 'amount' => 273.36, 'status' => 'pending')
      expect(plan.installments.last['due_date']).to eq('2027-05-24')
    end

    it 'keeps the application custom tuition in step so a later plan swap uses it' do
      plan.update_schedule!(total_amount: '2460', rows: prorated_rows)

      expect(application.reload.custom_tuition_amount).to eq(2460)
    end

    it 'rejects a schedule that does not add up to the total' do
      expect { plan.update_schedule!(total_amount: '2500', rows: prorated_rows) }
        .to raise_error(described_class::ScheduleError, /add up to \$2460.00 but total tuition is \$2500.00/)
      expect(plan.reload.installments.size).to eq(10)
    end

    it 'rejects due dates out of order' do
      rows = prorated_rows.dup
      rows[1] = rows[1].merge(due_date: '2026-09-01')

      expect { plan.update_schedule!(total_amount: '2460', rows: rows) }
        .to raise_error(described_class::ScheduleError, /#2 is due before installment #1/)
    end

    it 'rejects a missing amount' do
      rows = prorated_rows.dup
      rows[0] = rows[0].merge(amount: '')

      expect { plan.update_schedule!(total_amount: '2460', rows: rows) }
        .to raise_error(described_class::ScheduleError, /#1 needs an amount/)
    end

    context 'with a paid installment' do
      before do
        payment = create(:payment, enrollment_payment_plan: plan, program_enrollment: enrollment,
                                   amount: 280, installment_number: 1, payment_date: Date.new(2026, 8, 1))
        plan.mark_installment_paid!(0, payment)
      end

      it 'keeps it paid while later installments change' do
        rows = [keep_row(0)] + (1..8).map { |i| keep_row(i, amount: '315.00') }
        plan.update_schedule!(total_amount: '2800', rows: rows)

        expect(plan.reload.installments.first['status']).to eq('completed')
        expect(plan.installments.first['paid_at']).to be_present
        expect(plan.installments.size).to eq(9)
      end

      it 'refuses to change its amount' do
        rows = [keep_row(0, amount: '250.00')] + (1..9).map { |i| keep_row(i) }
        rows[1][:amount] = '310.00'

        expect { plan.update_schedule!(total_amount: '2800', rows: rows) }
          .to raise_error(described_class::ScheduleError, /#1 has been paid, so its date and amount/)
      end

      it 'refuses to remove it' do
        rows = (1..9).map { |i| keep_row(i) }
        rows[0][:amount] = '560.00'

        expect { plan.update_schedule!(total_amount: '2800', rows: rows) }
          .to raise_error(described_class::ScheduleError, /#1 has been paid, so it can't be removed/)
      end
    end

    context 'with a pending invoice' do
      let!(:invoice) do
        create(:payment, :pending, enrollment_payment_plan: plan, program_enrollment: enrollment,
                                   amount: 280, installment_number: 2, payment_date: Date.new(2026, 9, 1))
      end

      it 'moves the invoice to the edited amount and date' do
        rows = (0..9).map { |i| keep_row(i) }
        rows[1] = keep_row(1, due_date: '2026-09-28', amount: '273.36')
        rows[2][:amount] = '286.64'

        plan.update_schedule!(total_amount: '2800', rows: rows)

        expect(invoice.reload.amount).to eq(273.36)
        expect(invoice.payment_date).to eq(Date.new(2026, 9, 28))
      end

      it 'refuses to remove the invoiced installment' do
        rows = [keep_row(0)] + (2..9).map { |i| keep_row(i) }
        rows[0][:amount] = '560.00'

        expect { plan.update_schedule!(total_amount: '2800', rows: rows) }
          .to raise_error(described_class::ScheduleError, /#2 has an invoice/)
      end

      it 'ignores refunded invoices' do
        invoice.update!(status: 'refunded')

        expect { plan.update_schedule!(total_amount: '2460', rows: prorated_rows) }.not_to raise_error
      end
    end
  end
end
