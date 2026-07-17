# frozen_string_literal: true

# Stores the OAuth credentials for the Gmail mailbox that outgoing mail is sent
# from. Treated as a singleton: the most recent connected row is the active one.
class GmailIntegration < ApplicationRecord
	attribute :access_token, EncryptedString.new
	attribute :refresh_token, EncryptedString.new

	belongs_to :connected_by, class_name: 'User', optional: true

	scope :connected, -> { where(status: 'connected') }

	# The active integration, if any.
	def self.current
		connected.order(created_at: :desc).first
	end

	# Can the app actually send through this integration right now?
	def usable?
		status == 'connected' && refresh_token.present?
	end

	# Blank granted_scopes means the row predates scope tracking — assume ok.
	def send_scope_granted?
		granted_scopes.blank? || granted_scopes.include?('gmail.send')
	end

	# A valid access token, refreshing via the stored refresh token if expired.
	def fresh_access_token!
		refresh! if access_token.blank? || token_expired?
		access_token
	end

	def token_expired?
		token_expires_at.blank? || token_expires_at <= 1.minute.from_now
	end

	def refresh!
		client = GmailOauth.base_client(refresh_token: refresh_token)
		client.fetch_access_token!
		update!(access_token: client.access_token, token_expires_at: client.expires_at)
	end

	def disconnect!
		update!(status: 'disconnected', access_token: nil, refresh_token: nil)
	end
end
