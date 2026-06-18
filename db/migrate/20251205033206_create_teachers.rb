class CreateTeachers < ActiveRecord::Migration[7.2]
  def change
    create_table :teachers, id: :uuid do |t|
      t.string :first_name
      t.string :last_name
      t.string :email
      t.string :phone
      t.text :bio
      t.references :user, null: true, foreign_key: true, type: :uuid

      t.timestamps
    end
  end
end
