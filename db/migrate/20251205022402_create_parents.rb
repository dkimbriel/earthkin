class CreateParents < ActiveRecord::Migration[7.2]
  def change
    create_table :parents do |t|
      t.references :family, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true
      t.string :first_name
      t.string :last_name
      t.string :email
      t.string :phone

      t.timestamps
    end
  end
end
