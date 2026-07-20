class AddMuteAutomatedEmailsToEnrollmentApplications < ActiveRecord::Migration[7.2]
  def change
    add_column :enrollment_applications, :mute_automated_emails, :boolean, default: false, null: false
  end
end
