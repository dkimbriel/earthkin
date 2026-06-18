class ProgramEnrollment < ApplicationRecord
  belongs_to :child
  belongs_to :program
  belongs_to :enrollment_application, optional: true
  has_many :payments, dependent: :destroy
  has_one :enrollment_payment_plan, dependent: :destroy
  has_one :payment_plan, through: :enrollment_payment_plan

  validates :rate_per_class, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :status, presence: true, inclusion: { in: %w[pending confirmed cancelled] }

  before_create :set_enrolled_at

  # Financial calculations - delegate to EnrollmentPaymentPlan when available
  def total_owed
    return legacy_total_owed if enrollment_payment_plan.blank?
    enrollment_payment_plan.total_amount + enrollment_payment_plan.enrollment_fee
  end

  def total_paid
    return legacy_total_paid if enrollment_payment_plan.blank?
    payments.completed.sum(:amount)
  end

  def balance_due
    total_owed - total_paid
  end

  # Legacy methods for enrollments without payment plans
  def legacy_total_owed
    (rate_per_class || 0) * billable_classes.count
  end

  def legacy_total_paid
    payments.completed.sum(:amount)
  end

  def billable_classes
    classes = program.program_classes.where('date <= ?', Date.current)
    classes = classes.where('date < ?', cancelled_at) if cancelled_at.present?
    classes.order(:date)
  end

  # Workflow status helpers
  def can_request_enrollment_fee?
    workflow_status == 'meeting_completed'
  end

  def can_send_enrollment_forms?
    workflow_status == 'fee_paid'
  end

  def can_confirm_enrollment?
    workflow_status == 'signing_docs'
  end

  def advance_workflow_to!(new_status)
    update!(workflow_status: new_status)
  end

  private

  def set_enrolled_at
    self.enrolled_at ||= Time.current
  end
end
