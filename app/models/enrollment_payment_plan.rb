class EnrollmentPaymentPlan < ApplicationRecord
  include SoftDeletable

  # Raised when a locked-in plan can't be safely swapped (e.g. tuition
  # installments have already been paid against the current schedule).
  class PlanChangeError < StandardError; end
  # Raised when an admin-edited schedule is invalid; the message is shown to them.
  class ScheduleError < StandardError; end

  belongs_to :program_enrollment
  belongs_to :payment_plan
  has_many :payments, dependent: :destroy

  validates :total_amount, presence: true, numericality: { greater_than: 0 }
  validates :enrollment_fee, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # Swap the locked-in payment plan for a different one and rebuild the
  # installment schedule from it, keeping the original first-payment date. Used
  # when an admin corrects a plan chosen by mistake. Refuses to run once any
  # installment has been paid, so recorded payments can't be silently dropped.
  def change_plan!(new_plan, tuition_override: nil)
    if installments.any? { |i| i['status'] == 'completed' || i['paid_at'].present? }
      raise PlanChangeError, 'Cannot change the plan after a tuition installment has been paid. Adjust the installments manually instead.'
    end

    total = tuition_override || new_plan.total_amount
    update!(
      payment_plan: new_plan,
      total_amount: total,
      installments: new_plan.generate_schedule(schedule_start_date, total: total).map { |i| i.merge('paid_at' => nil) }
    )
  end

  # Replace the tuition total and installment schedule with an admin-edited
  # one (e.g. a prorated mid-year start with its own due dates). `rows` is an
  # array of { due_date:, amount:, original_index: } where original_index is the
  # row's position in the current schedule, or nil for a newly added row.
  #
  # Payments and Stripe sessions point at installments by position, so any
  # installment that is paid or already invoiced must stay at its index; paid
  # ones can't change at all, invoiced ones can change date/amount and their
  # pending invoice follows. The schedule must sum exactly to the total.
  def update_schedule!(total_amount:, rows:)
    total_cents = to_cents(total_amount)
    raise ScheduleError, 'Total tuition must be greater than zero.' unless total_cents&.positive?
    raise ScheduleError, 'A schedule needs at least one installment.' if rows.blank?

    new_installments = rows.each_with_index.map { |row, i| build_schedule_row(row, i) }
    check_schedule_order!(new_installments)
    check_schedule_sum!(new_installments, total_cents)
    check_locked_rows!(new_installments)

    transaction do
      update!(total_amount: BigDecimal(total_cents) / 100, installments: new_installments.map { |r| r.except(:original_index) })
      sync_pending_invoices!
      program_enrollment.enrollment_application&.update!(custom_tuition_amount: self.total_amount)
    end
  end

  def mark_enrollment_fee_paid!
    update!(
      enrollment_fee_paid: true,
      enrollment_fee_paid_at: Time.current
    )
  end

  def total_paid
    payments.where(status: 'completed').sum(:amount)
  end

  def tuition_paid
    payments.where(payment_type: 'tuition', status: 'completed').sum(:amount)
  end

  def balance_due
    total_amount + enrollment_fee - total_paid
  end

  def enrollment_fee_payment
    payments.find_by(payment_type: 'enrollment_fee', status: 'completed')
  end

  def next_installment
    installments.find { |i| i['status'] == 'pending' }
  end

  def overdue_installments
    installments.select do |i|
      i['status'] == 'pending' && Date.parse(i['due_date']) < Date.current
    end
  end

  def mark_installment_paid!(installment_index, payment)
    installment = installments[installment_index]
    return unless installment

    installment['status'] = 'completed'
    installment['paid_at'] = payment.payment_date.to_s
    save!
  end

  private

  def to_cents(value)
    (BigDecimal(value.to_s) * 100).round.to_i
  rescue ArgumentError, TypeError
    nil
  end

  # Normalise one submitted row into the stored installment shape, carrying
  # status/paid_at over from the row it replaces when that row was paid.
  def build_schedule_row(row, position)
    row = row.to_h.with_indifferent_access
    label = "Installment ##{position + 1}"

    due_date = begin
      Date.parse(row[:due_date].to_s)
    rescue ArgumentError, TypeError
      raise ScheduleError, "#{label} needs a valid due date."
    end

    cents = to_cents(row[:amount])
    raise ScheduleError, "#{label} needs an amount greater than zero." unless cents&.positive?

    original_index = row[:original_index].presence&.to_i
    # Only a row still in its original slot can carry a paid status over.
    original = original_index == position ? installments[position] : nil
    paid = original.present? && paid_installment?(original)

    {
      'due_date' => due_date.to_s,
      'amount' => (BigDecimal(cents) / 100).to_f,
      'status' => paid ? 'completed' : 'pending',
      'paid_at' => paid ? original['paid_at'] : nil,
      original_index: original_index
    }
  end

  def check_schedule_order!(rows)
    rows.each_cons(2).with_index do |(a, b), i|
      next if a['due_date'] <= b['due_date']

      raise ScheduleError, "Installment ##{i + 2} is due before installment ##{i + 1}. Put due dates in order."
    end
  end

  def check_schedule_sum!(rows, total_cents)
    sum_cents = rows.sum { |r| to_cents(r['amount']) }
    return if sum_cents == total_cents

    raise ScheduleError, format('Installments add up to $%.2f but total tuition is $%.2f.', sum_cents / 100.0, total_cents / 100.0)
  end

  # Paid and invoiced installments are referenced by position (Payment
  # installment_number, Stripe installment_index), so they must stay put.
  def check_locked_rows!(rows)
    invoiced = invoiced_installment_indexes

    installments.each_with_index do |original, i|
      paid = paid_installment?(original)
      next unless paid || invoiced.include?(i)

      kept = rows[i]
      unless kept && kept[:original_index] == i
        reason = paid ? 'has been paid' : 'has an invoice'
        raise ScheduleError, "Installment ##{i + 1} #{reason}, so it can't be removed or moved."
      end

      next unless paid
      next if kept['due_date'] == Date.parse(original['due_date'].to_s).to_s &&
              to_cents(kept['amount']) == to_cents(original['amount'])

      raise ScheduleError, "Installment ##{i + 1} has been paid, so its date and amount can't change."
    end
  end

  def paid_installment?(installment)
    installment['status'] == 'completed' || installment['paid_at'].present?
  end

  def tuition_invoices
    payments.where(payment_type: 'tuition').where.not(status: 'refunded').where.not(installment_number: nil)
  end

  def invoiced_installment_indexes
    tuition_invoices.pluck(:installment_number).map { |n| n - 1 }.to_set
  end

  # Keep unpaid invoices in step with the (possibly edited) schedule so a Pay
  # now link charges the current amount.
  def sync_pending_invoices!
    tuition_invoices.where(status: 'pending').find_each do |invoice|
      installment = installments[invoice.installment_number - 1]
      next unless installment

      invoice.update!(amount: installment['amount'], payment_date: Date.parse(installment['due_date'].to_s))
    end
  end

  # Preserve the original first-payment date when rebuilding the schedule so a
  # plan swap doesn't quietly shift due dates; fall back to the program start.
  def schedule_start_date
    first_due = installments.first && installments.first['due_date']
    return Date.parse(first_due.to_s) if first_due.present?

    program_enrollment.program.start_date || Date.current
  end
end
