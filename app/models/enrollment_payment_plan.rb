class EnrollmentPaymentPlan < ApplicationRecord
  belongs_to :program_enrollment
  belongs_to :payment_plan
  has_many :payments, dependent: :destroy

  validates :total_amount, presence: true, numericality: { greater_than: 0 }
  validates :enrollment_fee, presence: true, numericality: { greater_than_or_equal_to: 0 }

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
end
