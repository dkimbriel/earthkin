class ExtendProgramEnrollments < ActiveRecord::Migration[7.2]
  def change
    add_column :program_enrollments, :enrollment_application_id, :uuid
    add_column :program_enrollments, :workflow_status, :string, default: 'application_submitted'
    # Workflow: application_submitted → meeting_scheduled → meeting_completed
    # → fee_requested → fee_paid → forms_sent → enrolled

    add_foreign_key :program_enrollments, :enrollment_applications
    add_index :program_enrollments, :enrollment_application_id
    add_index :program_enrollments, :workflow_status
  end
end
