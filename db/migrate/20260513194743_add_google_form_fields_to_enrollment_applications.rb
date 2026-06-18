class AddGoogleFormFieldsToEnrollmentApplications < ActiveRecord::Migration[7.2]
  def change
    add_column :enrollment_applications, :child_race_ethnicity, :string
    add_column :enrollment_applications, :parent2_first_name, :string
    add_column :enrollment_applications, :parent2_last_name, :string
    add_column :enrollment_applications, :is_local, :string
    add_column :enrollment_applications, :local_area, :string
    add_column :enrollment_applications, :referral_source, :string
    add_column :enrollment_applications, :agreements, :jsonb, default: {}
  end
end
