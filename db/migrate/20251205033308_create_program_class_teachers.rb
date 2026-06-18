class CreateProgramClassTeachers < ActiveRecord::Migration[7.2]
  def change
    create_table :program_class_teachers, id: :uuid do |t|
      t.references :program_class, null: false, foreign_key: true, type: :uuid
      t.references :teacher, null: false, foreign_key: true, type: :uuid

      t.timestamps
    end
    add_index :program_class_teachers, [:program_class_id, :teacher_id], unique: true, name: 'index_program_class_teachers_unique'
  end
end
