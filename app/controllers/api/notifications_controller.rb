# frozen_string_literal: true

module Api
  class NotificationsController < BaseController
    before_action :require_admin!

    def index
      notifications = Notification.recent.limit(100)
      read_ids = current_user.notification_reads
                             .where(notification_id: notifications.map(&:id))
                             .pluck(:notification_id).to_set
      render json: {
        notifications: notifications.map { |n| n.as_json.merge(read: read_ids.include?(n.id)) },
        unread_count: Notification.unread_for(current_user).count
      }
    end

    def mark_read
      notification = Notification.find(params[:id])
      current_user.notification_reads
                  .find_or_create_by!(notification: notification) { |r| r.read_at = Time.current }
      render json: notification.as_json.merge(read: true)
    end

    def mark_all_read
      now = Time.current
      rows = Notification.unread_for(current_user).pluck(:id).map do |id|
        { notification_id: id, user_id: current_user.id, read_at: now, created_at: now, updated_at: now }
      end
      NotificationRead.insert_all(rows) if rows.any?
      render json: { unread_count: 0 }
    end
  end
end
