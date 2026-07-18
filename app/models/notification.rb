class Notification < ApplicationRecord
  belongs_to :enrollment_application, optional: true

  EVENT_TYPES = %w[meeting_scheduled payment_plan_selected form_signed].freeze

  validates :event_type, inclusion: { in: EVENT_TYPES }
  validates :title, presence: true

  scope :unread, -> { where(read_at: nil) }
  scope :recent, -> { order(created_at: :desc) }

  def read?
    read_at.present?
  end

  def mark_read!
    update!(read_at: Time.current) unless read?
  end

  def as_json(_options = {})
    {
      id: id,
      event_type: event_type,
      title: title,
      body: body,
      enrollment_application_id: enrollment_application_id,
      read: read?,
      read_at: read_at,
      created_at: created_at
    }
  end
end
