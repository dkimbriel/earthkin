class AddCancelledAtToProgramEnrollments < ActiveRecord::Migration[7.2]
  def change
    add_column :program_enrollments, :cancelled_at, :date
  end
end
