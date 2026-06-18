class AddCustomFeesToEnrollmentApplications < ActiveRecord::Migration[7.2]
  def change
    add_column :enrollment_applications, :custom_enrollment_fee, :decimal, precision: 8, scale: 2
    add_column :enrollment_applications, :custom_tuition_amount, :decimal, precision: 8, scale: 2
  end
end
