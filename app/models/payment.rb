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

  # Ensures the public pay-link token exists (backfills legacy rows) and returns it.
  def pay_token!
    return payment_token if payment_token.present?

    update!(payment_token: SecureRandom.urlsafe_base64(24))
    payment_token
  end

  # Absolute URL for the public "pay this invoice" page. Host comes from the
  # mailer URL options, matching EnrollmentApplication#payment_selection_url.
  def pay_url
    url_options = Rails.application.config.action_mailer.default_url_options || { host: 'localhost', port: 3000 }
    Rails.application.routes.url_helpers.invoice_payment_url(pay_token!, **url_options)
  end
end
