class CreateStaffDocuments < ActiveRecord::Migration[7.0]
	def change
		# A single document issued to one employee for signature. Unlike
		# enrollment forms, which read their text live from the template until
		# signing, a staff document copies the body at issue time: a written
		# warning or termination letter is specific to one person and one set of
		# facts, and editing the template later must never rewrite a letter
		# already sitting in someone's portal.
		create_table :staff_documents, id: :uuid do |t|
			t.references :teacher, type: :uuid, null: false, foreign_key: true
			t.references :form_template, type: :uuid, null: true, foreign_key: true
			t.references :issued_by, type: :uuid, null: true, foreign_key: { to_table: :users }

			t.string :title, null: false
			# The employee's role as of this notice. Snapshotted on the document
			# rather than read from the teacher record, since an HR record has to
			# reflect the position held at the time it was issued.
			t.string :employee_position
			t.text :body, null: false, default: ''
			t.string :status, null: false, default: 'pending'

			# Two-party signing: the employee acknowledges receipt, the director
			# counter-signs. Either may sign first; the document is complete only
			# when both have.
			t.string :employee_signed_by_name
			t.string :employee_signed_by_email
			t.string :employee_signature_ip
			t.datetime :employee_signed_at
			t.text :employee_comments

			t.string :director_signed_by_name
			t.string :director_signed_by_email
			t.string :director_signature_ip
			t.datetime :director_signed_at

			# Frozen at the first signature so both parties are demonstrably
			# signing the same text.
			t.text :body_snapshot
			t.jsonb :form_fields, null: false, default: {}
			t.jsonb :audit_log, null: false, default: []

			t.datetime :deleted_at
			t.timestamps
		end

		add_index :staff_documents, :status
		add_index :staff_documents, :deleted_at
	end
end
