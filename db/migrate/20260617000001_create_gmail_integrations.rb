class CreateGmailIntegrations < ActiveRecord::Migration[7.0]
	def change
		create_table :gmail_integrations, id: :uuid do |t|
			t.string :email, null: false
			t.text :access_token
			t.text :refresh_token
			t.datetime :token_expires_at
			t.string :status, null: false, default: 'connected'
			t.references :connected_by, type: :uuid, foreign_key: { to_table: :users }

			t.timestamps
		end
	end
end
