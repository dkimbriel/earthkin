class Payment < ApplicationRecord
  include SoftDeletable

  belongs_to :program_enrollment
  belongs_to :enrollment_payment_plan, optional: true
  has_many :emails, as: :emailable, dependent: :destroy

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :payment_date, presence: true
  validates :status, presence: true, inclusion: { in: %w[pending completed refunded] }
  validates :payment_type, inclusion: { in: %w[enrollment_fee tuition other] }

  scope :pending, -> { where(status: 'pending') }
  scope :completed, -> { where(status: 'completed') }
  scope :refunded, -> { where(status: 'refunded') }
  scope :enrollment_fees, -> { where(payment_type: 'enrollment_fee') }
  scope :tuition_payments, -> { where(payment_type: 'tuition') }

  def deleted_label
    "$#{amount} #{payment_type} payment"
  end
end
