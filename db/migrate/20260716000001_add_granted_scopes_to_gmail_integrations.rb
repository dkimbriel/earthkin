class AddGrantedScopesToGmailIntegrations < ActiveRecord::Migration[7.0]
	def change
		# What Google actually granted at consent time — the admin can uncheck
		# the send permission on the consent screen, leaving a connection that
		# refreshes tokens fine but can't send mail.
		add_column :gmail_integrations, :granted_scopes, :string
	end
end
