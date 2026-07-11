class CreateEnrollmentFormSignatures < ActiveRecord::Migration[7.0]
	def change
		# The text of each signable enrollment form; editable by admins.
		create_table :form_templates, id: :uuid do |t|
			t.string :key, null: false
			t.string :name, null: false
			t.text :body, null: false, default: ''
			t.timestamps
		end
		add_index :form_templates, :key, unique: true

		# One row per form a family must sign for a child.
		create_table :enrollment_form_signatures, id: :uuid do |t|
			t.references :child, type: :uuid, null: false, foreign_key: true
			t.references :form_template, type: :uuid, null: false, foreign_key: true
			t.references :enrollment_application, type: :uuid, foreign_key: true
			t.string :status, null: false, default: 'pending'
			t.string :signed_by_name
			t.string :signed_by_email
			t.string :signature_ip
			t.datetime :signed_at
			t.text :form_body_snapshot
			t.timestamps
		end
		add_index :enrollment_form_signatures, [:child_id, :form_template_id, :enrollment_application_id],
		          unique: true, name: 'index_form_signatures_uniqueness'
	end
end
