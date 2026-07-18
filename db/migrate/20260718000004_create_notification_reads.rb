# frozen_string_literal: true

# Read status is now tracked per user instead of on the notification itself,
# so each admin manages their own read/unread state independently.
class CreateNotificationReads < ActiveRecord::Migration[7.2]
  def change
    create_table :notification_reads, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :notification, null: false, type: :uuid, foreign_key: true
      t.references :user, null: false, type: :uuid, foreign_key: true
      t.datetime :read_at, null: false
      t.timestamps
    end

    add_index :notification_reads, %i[notification_id user_id], unique: true

    remove_index :notifications, :read_at
    remove_column :notifications, :read_at, :datetime
  end
end
