# frozen_string_literal: true

# Records that a specific user has read a specific notification. One row per
# (notification, user) pair; its absence means the notification is unread for
# that user.
class NotificationRead < ApplicationRecord
  belongs_to :notification
  belongs_to :user

  validates :notification_id, uniqueness: { scope: :user_id }
end
