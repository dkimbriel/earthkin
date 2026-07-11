class CreateContentItems < ActiveRecord::Migration[7.0]
	def change
		create_table :content_items, id: :uuid do |t|
			t.string :title, null: false
			t.string :url, null: false
			t.text :description
			t.string :category, null: false, default: 'general'
			t.string :visibility, null: false, default: 'all_staff'
			t.timestamps
		end

		create_table :content_item_teachers, id: :uuid do |t|
			t.references :content_item, type: :uuid, null: false, foreign_key: true
			t.references :teacher, type: :uuid, null: false, foreign_key: true
			t.timestamps
		end

		add_index :content_item_teachers, [:content_item_id, :teacher_id], unique: true
	end
end
