class Notification < ApplicationRecord
  belongs_to :enrollment_application, optional: true
  has_many :notification_reads, dependent: :delete_all

  EVENT_TYPES = %w[meeting_scheduled payment_plan_selected form_signed].freeze

  validates :event_type, inclusion: { in: EVENT_TYPES }
  validates :title, presence: true

  scope :recent, -> { order(created_at: :desc) }

  # Notifications that the given user has not marked read. Read status is
  # tracked per user via notification_reads, so each admin has their own.
  scope :unread_for, ->(user) {
    where.not(id: NotificationRead.where(user_id: user.id).select(:notification_id))
  }

  def as_json(_options = {})
    {
      id: id,
      event_type: event_type,
      title: title,
      body: body,
      enrollment_application_id: enrollment_application_id,
      created_at: created_at
    }
  end
end
