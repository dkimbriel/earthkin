class AdminNotificationMailer < ApplicationMailer
  # Emails a single admin notification to the connected mailbox (plus-aliased).
  def alert(notification_id)
    @notification = Notification.find(notification_id)
    to = AdminNotifier.alert_address
    return if to.blank?

    @portal_url = notifications_portal_url

    from = GmailIntegration.current&.email.presence || self.class.default[:from]
    mail(to: to, from: from, subject: "[Earthkin] #{@notification.title}")
  end

  private

  def notifications_portal_url
    base = Rails.application.routes.url_helpers.root_url(**(ActionMailer::Base.default_url_options || { host: 'localhost', port: 3000 }))
    "#{base.chomp('/')}/notifications"
  end
end
