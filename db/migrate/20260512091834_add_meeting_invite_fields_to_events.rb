class AddMeetingInviteFieldsToEvents < ActiveRecord::Migration[7.2]
  def change
    add_column :events, :proposed_dates, :jsonb, default: []
    add_column :events, :confirmation_token, :string
    add_index :events, :confirmation_token, unique: true

    # Allow scheduled_at to be null for pending_selection status
    change_column_null :events, :scheduled_at, true
  end
end
