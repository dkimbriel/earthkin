class EmailTrackingService
  def initialize(emailable)
    @emailable = emailable
  end

  # Creates a tracked Email record and delivers it immediately, in-process.
  # Delivery failures are recorded on the Email record (status "failed")
  # rather than raised, so a mail outage never aborts the calling workflow.
  def send_email(mailer_class, email_type, mailer_args = [], metadata = {})
    recipient = determine_recipient
    subject = generate_subject(mailer_class, email_type)

    email = @emailable.emails.create!(
      emailable: @emailable,
      mailer_class: mailer_class,
      email_type: email_type,
      recipient: recipient,
      subject: subject,
      status: 'queued',
      metadata: metadata
    )

    deliver(email, mailer_class, email_type, mailer_args)

    email
  end

  private

  def deliver(email, mailer_class, email_type, mailer_args)
    message = mailer_class.constantize.public_send(email_type, *mailer_args)

    # The mailer (or an admin-edited template) owns the real subject.
    email.update(html_body: capture_html_body(message), subject: message.subject.presence || email.subject)

    message.deliver_now
    email.mark_sent!
  rescue StandardError => e
    Rails.logger.error(
      "Email delivery failed (#{mailer_class}##{email_type}, email #{email.id}): #{e.class}: #{e.message}"
    )
    email.mark_failed!(e)
  end

  def capture_html_body(message)
    html_body = if message.html_part
      message.html_part.body.decoded
    elsif message.content_type&.include?('text/html')
      message.body.decoded
    else
      plain_body = message.body.decoded
      "<html><body><pre>#{plain_body}</pre></body></html>"
    end

    # Inline attachment (cid:) URLs only resolve inside a mail client, so
    # point them at the public logo for the in-app preview.
    html_body.gsub(/cid:[^"']*/, '/logo.png')
  end

  def determine_recipient
    recipient = case @emailable
    when EnrollmentApplication
      @emailable.parent_email
    when Payment
      @emailable.program_enrollment.child.family.parents.pluck(:email)
    when Parent
      @emailable.email
    else
      raise "Unknown emailable type: #{@emailable.class}"
    end

    Array(recipient).join(', ')
  end

  def generate_subject(mailer_class, email_type)
    case [mailer_class, email_type]
    when ['EnrollmentMailer', 'meeting_scheduled']
      "🌿 Nature Preschool: Meet-n-Greet Scheduled"
    when ['EnrollmentMailer', 'meeting_invite']
      "🌿 Nature Preschool: Schedule A Meet-n-Greet"
    when ['EnrollmentMailer', 'enrollment_fee_request']
      "Next Steps: Enrollment Fee & Handbook"
    when ['EnrollmentMailer', 'enrollment_confirmed']
      "Enrollment Confirmed! 🎉"
    when ['EnrollmentMailer', 'enrollment_invite']
      program_name = @emailable.respond_to?(:program) ? @emailable.program.name : 'Nature Preschool'
      "You're Invited to Apply: #{program_name}"
    when ['PaymentMailer', 'invoice']
      "Payment Invoice"
    when ['PaymentMailer', 'receipt']
      "Payment Receipt"
    when ['ParentMailer', 'welcome_email']
      "Welcome to Earthkin Nature School - Your Account is Ready!"
    when ['ParentMailer', 'application_status_update']
      "Update on Your Enrollment Application"
    else
      "Nature Preschool Update"
    end
  end
end
