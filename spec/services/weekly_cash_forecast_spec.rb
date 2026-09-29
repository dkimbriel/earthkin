require 'rails_helper'

RSpec.describe WeeklyCashForecast do
  # A Wednesday: this week starts Mon 9/28, the window runs Mon 8/31 to Sun 12/20.
  let(:today) { Date.new(2026, 9, 30) }
  let(:forecast) { described_class.new(today: today).call }

  let(:program) { create(:program, name: 'Nature Preschool') }
  let(:child) { create(:child, first_name: 'Theo', last_name: 'McLean') }
  let(:enrollment) { create(:program_enrollment, program: program, child: child, status: 'confirmed') }

  def week(start)
    forecast[:weeks].find { |w| w[:week_start] == Date.parse(start) }
  end

  def schedule(*rows)
    rows.map { |due, amount, status = 'pending'| { 'due_date' => due, 'amount' => amount, 'status' => status, 'paid_at' => nil } }
  end

  it 'covers 4 weeks back and 12 ahead, Monday start' do
    starts = forecast[:weeks].map { |w| w[:week_start] }

    expect(starts.size).to eq(16)
    expect(starts.first).to eq(Date.new(2026, 8, 31))
    expect(starts.last).to eq(Date.new(2026, 12, 14))
    expect(forecast[:weeks].select { |w| w[:current] }.map { |w| w[:week_start] }).to eq([Date.new(2026, 9, 28)])
  end

  it 'puts pending installments in the week they fall due' do
    create(:enrollment_payment_plan, program_enrollment: enrollment, total_amount: 546.69,
                                     installments: schedule(['2026-09-28', 273.36], ['2026-10-24', 273.33]))

    expect(week('2026-09-28')).to include(outstanding: 273.36, collected: 0)
    expect(week('2026-10-19')[:lines].first).to include(label: 'Installment 2 of 2', status: 'due', child_name: 'Theo McLean',
                                                        program_name: 'Nature Preschool', enrollment_id: enrollment.id)
    expect(forecast[:totals][:expected_upcoming]).to eq(546.69)
  end

  it 'counts completed payments as collected on their payment date, whatever the type' do
    create(:payment, program_enrollment: enrollment, payment_type: 'enrollment_fee', amount: 150, payment_date: '2026-09-02')
    create(:payment, program_enrollment: enrollment, payment_type: 'tuition', amount: 280, payment_date: '2026-09-29')

    expect(week('2026-08-31')).to include(collected: 150)
    expect(week('2026-08-31')[:lines].first).to include(label: 'Enrollment fee', status: 'paid')
    expect(week('2026-09-28')).to include(collected: 280)
    expect(forecast[:totals][:collected_recent]).to eq(430)
  end

  it "doesn't count an installment's invoice on top of the installment" do
    plan = create(:enrollment_payment_plan, program_enrollment: enrollment, installments: schedule(['2026-10-24', 280]))
    create(:payment, program_enrollment: enrollment, enrollment_payment_plan: plan, status: 'pending',
                     amount: 280, payment_date: '2026-10-24', installment_number: 1)

    expect(week('2026-10-19')[:outstanding]).to eq(280)
  end

  it 'counts a manual pending invoice by its date' do
    create(:payment, program_enrollment: enrollment, payment_type: 'other', status: 'pending', amount: 45, payment_date: '2026-10-07')

    expect(week('2026-10-05')).to include(outstanding: 45)
    expect(week('2026-10-05')[:lines].first).to include(label: 'Payment', status: 'due')
  end

  it 'leaves out cancelled enrollments, deleted plans, and refunded payments' do
    cancelled = create(:program_enrollment, program: program, status: 'cancelled')
    create(:enrollment_payment_plan, program_enrollment: cancelled, installments: schedule(['2026-10-24', 280]))
    create(:enrollment_payment_plan, program_enrollment: enrollment, installments: schedule(['2026-10-24', 300])).soft_delete!
    create(:payment, program_enrollment: enrollment, status: 'refunded', amount: 99, payment_date: '2026-09-29')

    expect(forecast[:weeks].sum { |w| w[:outstanding] + w[:collected] }).to eq(0)
  end

  it 'marks unpaid past-due lines overdue and totals overdue from before the window too' do
    create(:enrollment_payment_plan, program_enrollment: enrollment,
                                     installments: schedule(['2026-07-24', 280], ['2026-09-24', 280], ['2026-09-24', 280, 'completed']))

    expect(week('2026-09-21')[:lines].map { |l| l[:status] }).to eq(%w[overdue])
    expect(forecast[:totals][:overdue]).to eq(560)
  end

  it 'counts upcoming classes of a legacy per-class enrollment' do
    legacy = create(:program_enrollment, program: program, child: child, status: 'confirmed', rate_per_class: 35)
    create(:program_class, program: program, date: Date.new(2026, 10, 1))
    create(:program_class, program: program, date: Date.new(2026, 10, 6))
    create(:program_class, program: program, date: Date.new(2026, 9, 29)) # before today: not counted
    create(:program_class, program: program, date: Date.new(2026, 9, 22)) # past week: not counted

    expect(week('2026-09-28')[:outstanding]).to eq(35)
    expect(week('2026-10-05')[:outstanding]).to eq(35)
    expect(week('2026-09-21')[:outstanding]).to eq(0)
    expect(week('2026-10-05')[:lines].first[:enrollment_id]).to eq(legacy.id)
  end
end
