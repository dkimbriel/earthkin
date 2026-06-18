class EnrollmentEmailJob
  include Sidekiq::Job

  def perform(mailer_method, *args)
    # Email ID is passed as the last argument
    # Extract it and use remaining args for the mailer
    email_id = args.pop
    mailer_args = args

    # Find the email record
    email = Email.find(email_id) if email_id.present?

    begin
      # Generate the email message
      message = EnrollmentMailer.public_send(mailer_method, *mailer_args)

      # Capture the HTML body
      html_body = if message.html_part
        message.html_part.body.decoded
      elsif message.content_type&.include?('text/html')
        message.body.decoded
      else
        # If no HTML, wrap plain text in basic HTML
        plain_body = message.body.decoded
        "<html><body><pre>#{plain_body}</pre></body></html>"
      end

      # Replace attachment URLs with absolute URLs for preview
      # This fixes broken images when viewing email preview in the browser
      # CID URLs look like cid:6a0323474307d_88cb3cdc-435@MacBookPro.mail
      html_body = html_body.gsub(/cid:[^"']*/, '/logo.png')

      # Store the HTML body
      email&.update(html_body: html_body)

      # Send the email
      message.deliver_now

      # Mark as sent
      email&.mark_sent!
    rescue StandardError => e
      # Mark as failed
      email&.mark_failed!(e)
      raise # Re-raise to let Sidekiq handle retry logic
    end
  end
end
