# frozen_string_literal: true

require 'google/apis/gmail_v1'

# ActionMailer delivery method that sends mail through the Gmail API using the
# OAuth credentials stored in GmailIntegration. Registered as :gmail_api in
# config/initializers/gmail_mailer.rb.
class GmailApiDelivery
	def initialize(settings = {})
		@settings = settings
	end

	def deliver!(mail)
		integration = GmailIntegration.current
		raise 'Gmail integration is not connected; cannot send mail.' unless integration&.usable?

		service = Google::Apis::GmailV1::GmailService.new
		service.authorization = Signet::OAuth2::Client.new(access_token: integration.fresh_access_token!)

		message = Google::Apis::GmailV1::Message.new(
			raw: Base64.urlsafe_encode64(mail.to_s)
		)
		service.send_user_message('me', message)
	rescue Signet::AuthorizationError, Google::Apis::AuthorizationError => e
		# The stored refresh token was revoked or expired (Google expires them
		# weekly while the OAuth app is in "Testing" status).
		raise "The Gmail connection has expired — an admin needs to reconnect it under Integrations. (#{e.class})"
	end
end
