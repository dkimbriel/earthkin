# frozen_string_literal: true

module Api
	module Admin
		# JSON endpoints backing the React Integrations page: report connection
		# status and disconnect the mailbox.
		class IntegrationsController < Api::BaseController
			before_action :require_super_admin!

			# GET /api/admin/integrations/gmail
			def gmail
				render json: gmail_status(GmailIntegration.current)
			end

			# DELETE /api/admin/integrations/gmail
			def disconnect_gmail
				GmailIntegration.current&.disconnect!
				render json: gmail_status(GmailIntegration.current)
			end

			private

			def gmail_status(integration)
				{
					connected: integration&.usable? || false,
					configured: GmailOauth.configured?,
					email: integration&.email,
					connected_at: integration&.updated_at,
					connected_by: integration&.connected_by&.email
				}
			end

			def require_super_admin!
				return if current_user&.super_admin?

				render json: { error: 'Forbidden' }, status: :forbidden
			end
		end
	end
end
