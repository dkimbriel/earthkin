# frozen_string_literal: true

module Admin
	# Server-side OAuth redirect flow for connecting the Gmail mailbox. These are
	# full-page redirects (the browser leaves the SPA, visits Google, and returns),
	# so they live outside the JSON API. On completion they redirect back to the
	# React Integrations page with a ?gmail= status param.
	class IntegrationsController < ApplicationController
		before_action :authenticate_user!
		before_action :require_super_admin!

		RETURN_PATH = '/integrations'

		# GET /admin/integrations/gmail/connect
		def gmail_connect
			return redirect_to "#{RETURN_PATH}?gmail=not_configured" unless GmailOauth.configured?

			state = SecureRandom.hex(24)
			session[:gmail_oauth_state] = state
			redirect_to GmailOauth.authorization_url(state: state), allow_other_host: true
		end

		# GET /admin/integrations/gmail/callback
		def gmail_callback
			return redirect_to "#{RETURN_PATH}?gmail=error" unless valid_callback?

			save_integration!(GmailOauth.exchange_code(params[:code]))
			redirect_to "#{RETURN_PATH}?gmail=connected"
		rescue StandardError => e
			Rails.logger.error("Gmail OAuth callback failed: #{e.class}: #{e.message}")
			redirect_to "#{RETURN_PATH}?gmail=error"
		end

		private

		def valid_callback?
			expected_state = session.delete(:gmail_oauth_state)
			params[:error].blank? && params[:state].present? && params[:state] == expected_state
		end

		def save_integration!(client)
			integration = GmailIntegration.current || GmailIntegration.new
			integration.update!(
				email: GmailOauth.fetch_email(client.access_token),
				access_token: client.access_token,
				refresh_token: client.refresh_token,
				token_expires_at: client.expires_at,
				status: 'connected',
				connected_by: current_user
			)
		end

		def require_super_admin!
			redirect_to '/' unless current_user&.super_admin?
		end
	end
end
