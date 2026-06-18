class AddParent2ContactToEnrollmentApplications < ActiveRecord::Migration[7.2]
  def change
    add_column :enrollment_applications, :parent2_email, :string
    add_column :enrollment_applications, :parent2_phone, :string
  end
end
