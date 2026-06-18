class EmailTrackingService
  def initialize(emailable)
    @emailable = emailable
  end

  def queue_email(mailer_class, email_type, mailer_args = [], metadata = {})
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

    # Pass email_id as last positional argument (Sidekiq doesn't support keyword args)
    EnrollmentEmailJob.perform_async(email_type, *mailer_args, email.id)

    email
  end

  private

  def determine_recipient
    case @emailable
    when EnrollmentApplication
      @emailable.parent_email
    when Payment
      @emailable.program_enrollment.child.family.parents.pluck(:email)
    when Parent
      @emailable.email
    else
      raise "Unknown emailable type: #{@emailable.class}"
    end
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
