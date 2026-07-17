# frozen_string_literal: true

require 'signet/oauth_2/client'
require 'net/http'

# Helpers for the Google OAuth2 authorization-code flow used to connect the
# Earthkin Gmail mailbox. Credentials come from env vars created in the Google
# Cloud Console (see docs/gmail_integration_setup.md).
module GmailOauth
	# gmail.send lets us send mail as the connected account; email/openid let us
	# read back which address was connected.
	SCOPE = [
		'https://www.googleapis.com/auth/gmail.send',
		'email',
		'openid'
	].join(' ').freeze

	AUTH_URI = 'https://accounts.google.com/o/oauth2/auth'
	TOKEN_URI = 'https://oauth2.googleapis.com/token'
	USERINFO_URI = 'https://www.googleapis.com/oauth2/v3/userinfo'

	module_function

	def client_id
		Rails.application.credentials.dig(:google, :oauth_client_id) || ENV.fetch('GOOGLE_CLIENT_ID', nil)
	end

	def client_secret
		Rails.application.credentials.dig(:google, :oauth_client_secret) || ENV.fetch('GOOGLE_CLIENT_SECRET', nil)
	end

	def redirect_uri
		Rails.application.credentials.dig(:google, :oauth_redirect_uri) ||
			ENV['GOOGLE_REDIRECT_URI'] ||
			'http://localhost:3000/admin/integrations/gmail/callback'
	end

	def configured?
		client_id.present? && client_secret.present?
	end

	def base_client(extra = {})
		Signet::OAuth2::Client.new({
			client_id: client_id,
			client_secret: client_secret,
			authorization_uri: AUTH_URI,
			token_credential_uri: TOKEN_URI,
			scope: SCOPE,
			redirect_uri: redirect_uri
		}.merge(extra))
	end

	# URL to send the admin to Google's consent screen. access_type=offline +
	# prompt=consent guarantees Google returns a refresh token.
	def authorization_url(state:)
		base_client.authorization_uri(
			access_type: 'offline',
			prompt: 'consent',
			include_granted_scopes: 'true',
			state: state
		).to_s
	end

	# Exchange the authorization code for tokens. Returns the Signet client,
	# which carries access_token, refresh_token and expires_at.
	def exchange_code(code)
		client = base_client(code: code)
		client.fetch_access_token!
		client
	end

	# Google's consent screen lets the user uncheck individual permissions, so
	# a successful token exchange doesn't guarantee we can actually send mail.
	def send_scope_granted?(client)
		granted_scopes(client).include?('gmail.send')
	end

	def granted_scopes(client)
		Array(client.scope).join(' ')
	end

	# Look up the email address of the account that just authorized.
	def fetch_email(access_token)
		uri = URI(USERINFO_URI)
		request = Net::HTTP::Get.new(uri)
		request['Authorization'] = "Bearer #{access_token}"
		response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
		JSON.parse(response.body)['email']
	rescue StandardError => e
		Rails.logger.warn("GmailOauth#fetch_email failed: #{e.message}")
		nil
	end
end
