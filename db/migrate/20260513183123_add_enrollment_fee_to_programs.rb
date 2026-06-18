class AddEnrollmentFeeToPrograms < ActiveRecord::Migration[7.2]
  def change
    add_column :programs, :enrollment_fee, :decimal, precision: 10, scale: 2, default: 150.00
  end
end
