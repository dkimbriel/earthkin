class CreateNotifications < ActiveRecord::Migration[7.2]
  def change
    # Admin-facing alerts for key parent-driven events. Each row is both shown
    # in the in-app notifications inbox and emailed to the connected mailbox.
    create_table :notifications, id: :uuid do |t|
      t.string :event_type, null: false
      t.string :title, null: false
      t.text :body
      t.references :enrollment_application, type: :uuid, foreign_key: true
      t.datetime :read_at
      t.timestamps
    end
    add_index :notifications, :created_at
    add_index :notifications, :read_at
  end
end
