class CreatePrograms < ActiveRecord::Migration[7.2]
  def change
    create_table :programs do |t|
      t.string :name
      t.text :description
      t.date :start_date
      t.date :end_date
      t.integer :capacity

      t.timestamps
    end
  end
end
