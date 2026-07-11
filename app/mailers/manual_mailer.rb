# Sends one-off emails drafted by an admin in the portal. The draft's
# rendered HTML is stored on the Email record itself.
class ManualMailer < ApplicationMailer
  def compose(email_id)
    email = Email.find(email_id)
    body_html = email.html_body.to_s

    mail(to: email.recipient, subject: email.subject) do |format|
      format.html { render html: body_html.html_safe, layout: 'mailer' }
    end
  end
end
