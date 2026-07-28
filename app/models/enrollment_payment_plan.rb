class EnrollmentPaymentPlan < ApplicationRecord
  include SoftDeletable

  # Raised when a locked-in plan can't be safely swapped (e.g. tuition
  # installments have already been paid against the current schedule).
  class PlanChangeError < StandardError; end

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

    update!(
      payment_plan: new_plan,
      total_amount: tuition_override || new_plan.total_amount,
      installments: new_plan.generate_schedule(schedule_start_date).map { |i| i.merge('paid_at' => nil) }
    )
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

  # Preserve the original first-payment date when rebuilding the schedule so a
  # plan swap doesn't quietly shift due dates; fall back to the program start.
  def schedule_start_date
    first_due = installments.first && installments.first['due_date']
    return Date.parse(first_due.to_s) if first_due.present?

    program_enrollment.program.start_date || Date.current
  end
end
