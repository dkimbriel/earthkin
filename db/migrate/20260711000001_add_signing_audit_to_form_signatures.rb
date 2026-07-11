class AddSigningAuditToFormSignatures < ActiveRecord::Migration[7.0]
	def change
		# Parents' answers to the questions a form asks (contacts, medical
		# details, medication instructions) — captured alongside the signature.
		add_column :enrollment_form_signatures, :response_text, :text

		# DocuSign-style event trail: issued / viewed / signed entries with
		# timestamps, actor, IP, user agent, and a document checksum at signing.
		add_column :enrollment_form_signatures, :audit_log, :jsonb, null: false, default: []
	end
end
