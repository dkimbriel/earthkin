class CreateEnrollmentApplications < ActiveRecord::Migration[7.2]
  def change
    create_table :enrollment_applications, id: :uuid do |t|
      t.references :family, type: :uuid, foreign_key: true
      t.references :program, type: :uuid, null: false, foreign_key: true
      t.references :child, type: :uuid, foreign_key: true
      t.references :program_enrollment, type: :uuid, foreign_key: true

      # Workflow status
      # submitted → reviewed → meeting_scheduled → meeting_completed
      # → fee_requested → fee_paid → enrolled → declined
      t.string :status, null: false, default: 'submitted'

      # Parent info (captured before parent/family records exist)
      t.string :parent_first_name
      t.string :parent_last_name
      t.string :parent_email
      t.string :parent_phone

      # Child info (captured before child record exists)
      t.string :child_first_name
      t.string :child_last_name
      t.date :child_date_of_birth

      # Application details
      t.text :why_interested
      t.text :child_description
      t.text :special_needs
      t.text :dietary_restrictions
      t.text :previous_school_experience
      t.text :parent_expectations

      # Admin notes
      t.text :admin_notes

      # Workflow timestamps
      t.datetime :submitted_at
      t.datetime :reviewed_at
      t.datetime :declined_at

      t.timestamps
    end

    add_index :enrollment_applications, :status
    add_index :enrollment_applications, :parent_email
  end
end
