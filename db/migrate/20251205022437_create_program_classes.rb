class CreateProgramClasses < ActiveRecord::Migration[7.2]
  def change
    create_table :program_classes do |t|
      t.references :program, null: false, foreign_key: true
      t.string :name
      t.date :date
      t.time :start_time
      t.time :end_time
      t.string :location

      t.timestamps
    end
  end
end
