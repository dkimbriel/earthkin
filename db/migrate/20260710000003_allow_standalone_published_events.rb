class AllowStandalonePublishedEvents < ActiveRecord::Migration[7.0]
	def change
		# Manually created school events (open house, field trips...) aren't tied
		# to an enrollment application.
		change_column_null :events, :eventable_type, true
		change_column_null :events, :eventable_id, true

		# Published events appear on the parent portal calendar.
		add_column :events, :published, :boolean, default: false, null: false
	end
end
