class AddVisibleToFamiliesToContentItems < ActiveRecord::Migration[7.0]
	def change
		# Families visibility is independent of staff visibility — a document
		# (e.g. the Family Handbook) can be shown to all staff AND families.
		add_column :content_items, :visible_to_families, :boolean, null: false, default: false
	end
end
