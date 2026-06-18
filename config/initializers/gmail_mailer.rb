# frozen_string_literal: true

# Register the Gmail API delivery method so mailers can use
# `config.action_mailer.delivery_method = :gmail_api`.
ActiveSupport.on_load(:action_mailer) do
	ActionMailer::Base.add_delivery_method :gmail_api, GmailApiDelivery
end
