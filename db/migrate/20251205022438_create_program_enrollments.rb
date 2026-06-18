class CreateProgramEnrollments < ActiveRecord::Migration[7.2]
  def change
    create_table :program_enrollments do |t|
      t.references :child, null: false, foreign_key: true
      t.references :program, null: false, foreign_key: true
      t.string :status, default: 'pending', null: false
      t.decimal :rate_per_class, precision: 8, scale: 2, null: false
      t.datetime :enrolled_at

      t.timestamps
    end
  end
end
