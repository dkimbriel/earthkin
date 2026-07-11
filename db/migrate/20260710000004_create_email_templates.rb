class CreateEmailTemplates < ActiveRecord::Migration[7.0]
	def change
		create_table :email_templates, id: :uuid do |t|
			# When key is set, the template overrides the matching workflow email
			# (e.g. 'enrollment_fee_request'). Keyless templates are reusable
			# starting points for manual emails.
			t.string :key
			t.string :name, null: false
			t.string :subject, null: false
			t.text :body, null: false
			t.timestamps
		end
		add_index :email_templates, :key, unique: true, where: 'key IS NOT NULL'

		# Manual one-off emails aren't tied to an application/payment/parent.
		change_column_null :emails, :emailable_type, true
		change_column_null :emails, :emailable_id, true
	end
end
