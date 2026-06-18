class AddScheduleFieldsToPrograms < ActiveRecord::Migration[7.2]
  def change
    add_column :programs, :class_days, :string
    add_column :programs, :start_time, :time
    add_column :programs, :end_time, :time
  end
end
