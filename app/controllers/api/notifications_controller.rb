# frozen_string_literal: true

module Api
  class NotificationsController < BaseController
    before_action :require_admin!

    def index
      notifications = Notification.recent.limit(100)
      render json: {
        notifications: notifications.as_json,
        unread_count: Notification.unread.count
      }
    end

    def mark_read
      notification = Notification.find(params[:id])
      notification.mark_read!
      render json: notification.as_json
    end

    def mark_all_read
      Notification.unread.update_all(read_at: Time.current)
      render json: { unread_count: 0 }
    end
  end
end
