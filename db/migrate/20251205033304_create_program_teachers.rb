class CreateProgramTeachers < ActiveRecord::Migration[7.2]
  def change
    create_table :program_teachers, id: :uuid do |t|
      t.references :program, null: false, foreign_key: true, type: :uuid
      t.references :teacher, null: false, foreign_key: true, type: :uuid

      t.timestamps
    end
    add_index :program_teachers, [:program_id, :teacher_id], unique: true
  end
end
