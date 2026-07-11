class AddRoleToUsers < ActiveRecord::Migration[7.0]
	def up
		add_column :users, :role, :string, null: false, default: 'parent'

		# Backfill from existing associations: teacher-linked users become
		# teachers, parent-linked users stay parents, everyone else (staff
		# accounts created before roles existed) becomes an admin.
		execute <<~SQL
			UPDATE users SET role = 'teacher'
			WHERE id IN (SELECT user_id FROM teachers WHERE user_id IS NOT NULL)
		SQL
		execute <<~SQL
			UPDATE users SET role = 'admin'
			WHERE id NOT IN (
				SELECT user_id FROM teachers WHERE user_id IS NOT NULL
				UNION
				SELECT user_id FROM parents WHERE user_id IS NOT NULL
			)
		SQL
	end

	def down
		remove_column :users, :role
	end
end
