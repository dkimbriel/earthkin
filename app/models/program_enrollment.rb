class ProgramEnrollment < ApplicationRecord
  include SoftDeletable

  belongs_to :child
  belongs_to :program
  belongs_to :enrollment_application, optional: true
  has_many :payments, dependent: :destroy
  has_one :enrollment_payment_plan, dependent: :destroy
  has_one :payment_plan, through: :enrollment_payment_plan

  cascades_soft_delete :payments, :enrollment_payment_plan

  validates :rate_per_class, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :status, presence: true, inclusion: { in: %w[pending confirmed cancelled] }

  # Enrollments that count as "active" — a family currently enrolled/pending,
  # not cancelled. Used to block deleting a program that still has them.
  scope :active, -> { where(status: %w[pending confirmed]).where(cancelled_at: nil) }

  before_create :set_enrolled_at

  # When an enrollment is cancelled, walk its application back out of the
  # terminal "enrolled" state (see #revert_orphaned_application!). Soft-delete
  # is handled separately because it skips callbacks.
  after_update :revert_orphaned_application!, if: :just_cancelled?

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

  # Soft-deleting an enrollment removes it from enrolled_count, so keep the
  # application in sync too. Wrap in one transaction so the enrollment and the
  # application never disagree. (SoftDeletable#soft_delete! uses update_column,
  # which skips the after_update callback, so we hook it explicitly here.)
  def soft_delete!(timestamp = Time.current)
    return self if deleted?

    self.class.transaction do
      super
      revert_orphaned_application!
    end
    self
  end

  private

  def set_enrolled_at
    self.enrolled_at ||= Time.current
  end

  def just_cancelled?
    saved_change_to_status? && status == 'cancelled'
  end

  # An enrollment that is cancelled or deleted no longer counts toward the
  # program, but its application can be stranded in the terminal "enrolled"
  # state — showing "Enrolled" while the program reads zero enrollments. Walk
  # the application back to the last pre-enrolled step so the two stay
  # consistent and an admin can re-confirm if the removal was a mistake.
  def revert_orphaned_application!
    app = enrollment_application
    return unless app&.status == 'enrolled'

    app.update!(status: 'signing_docs')
  end
end
