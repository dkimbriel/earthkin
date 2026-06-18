class CreateChildren < ActiveRecord::Migration[7.2]
	def change
		create_table :children do |t|
			t.references :family, null: false, foreign_key: true
			t.string :first_name
			t.string :last_name

			t.timestamps
		end
	end
end
