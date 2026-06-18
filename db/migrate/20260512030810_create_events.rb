class CreateEvents < ActiveRecord::Migration[7.2]
  def change
    create_table :events, id: :uuid do |t|
      # Polymorphic association - can belong to enrollment_application, program, family, etc.
      t.references :eventable, type: :uuid, polymorphic: true, null: false
      t.references :location, type: :uuid, foreign_key: true

      # Event type: meet_and_greet, orientation, field_trip, parent_meeting, open_house, etc.
      t.string :event_type, null: false

      t.string :title
      t.text :description

      t.datetime :scheduled_at, null: false
      t.datetime :completed_at
      t.datetime :cancelled_at

      # Status: scheduled → confirmed → completed → cancelled → rescheduled
      t.string :status, null: false, default: 'scheduled'

      t.text :notes
      t.text :outcome_notes

      t.timestamps
    end

    add_index :events, :event_type
    add_index :events, :scheduled_at
    add_index :events, :status
  end
end
