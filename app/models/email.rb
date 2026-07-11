class Email < ApplicationRecord
  belongs_to :emailable, polymorphic: true, optional: true

  STATUSES = %w[draft queued sent failed bounced].freeze
  MAILER_CLASSES = %w[EnrollmentMailer PaymentMailer ParentMailer ManualMailer].freeze

  validates :email_type, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :mailer_class, inclusion: { in: MAILER_CLASSES }
  validates :recipient, :subject, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :by_type, ->(type) { where(email_type: type) }
  scope :sent, -> { where(status: 'sent') }
  scope :failed, -> { where(status: 'failed') }
  scope :drafts, -> { where(status: 'draft') }
  scope :for_mailer, ->(mailer) { where(mailer_class: mailer) }

  def draft?
    status == 'draft'
  end

  def mark_sent!
    update!(status: 'sent', sent_at: Time.current)
  end

  def mark_failed!(error)
    update!(status: 'failed', failed_at: Time.current, error_message: error.to_s)
  end

  def type_label
    email_type.titleize
  end

  def status_color
    case status
    when 'sent' then 'success'
    when 'failed', 'bounced' then 'error'
    when 'queued' then 'warning'
    when 'draft' then 'info'
    else 'default'
    end
  end
end
