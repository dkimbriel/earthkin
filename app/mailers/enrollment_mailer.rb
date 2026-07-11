class EnrollmentMailer < ApplicationMailer
  default from: ENV['MAILER_FROM'] || 'Earthkin Nature School <earthkinnatureschool@gmail.com>'

  # Meet-n-Greet Scheduled
  # Sent when meeting is scheduled (confirmation after parent selects date)
  def meeting_scheduled(event_id)
    @event = Event.includes(:eventable, :location).find(event_id)
    @application = @event.eventable
    @program = @application.program
    @location = @event.location
    @payment_plans = PaymentPlan.where(program: @program, active: true).order(:display_order)

    if (template = EmailTemplate.for('meeting_scheduled'))
      return templated_mail(template, to: @application.parent_email, vars: {
        parent_name: @application.parent_first_name,
        child_name: @application.child_first_name,
        program_name: @program.name,
        meeting_datetime: @event.scheduled_at&.strftime('%B %d at %I:%M %p'),
        location_name: @location&.name
      })
    end

    mail(
      to: @application.parent_email,
      subject: "🌿 Nature Preschool: Meet-n-Greet Scheduled - #{@event.scheduled_at.strftime('%B %d at %I:%M %p')}"
    )
  end

  # Meeting Invite
  # Sent to invite parent to select a meet-n-greet date from proposed options
  def meeting_invite(event_id, base_url)
    @event = Event.includes(:eventable, :location).find(event_id)
    @application = @event.eventable
    @program = @application.program
    @location = @event.location
    @base_url = base_url
    @payment_plans = PaymentPlan.where(program: @program, active: true).order(:display_order)

    mail(
      to: @application.parent_email,
      subject: "🌿 Nature Preschool: Schedule A Meet-n-Greet"
    )
  end

  # Email 3: Enrollment Fee Request
  # Sent after meeting is completed
  def enrollment_fee_request(enrollment_application_id)
    @application = EnrollmentApplication.includes(:events, program: { program_classes: :location }).find(enrollment_application_id)
    @program = @application.program
    @meeting_event = @application.events.find_by(event_type: 'meet_and_greet', status: 'completed')
    @location = @meeting_event&.location || @program.program_classes.first&.location
    @payment_plans = PaymentPlan.where(program: @program, active: true).order(:display_order)

    if (template = EmailTemplate.for('enrollment_fee_request'))
      return templated_mail(template, to: @application.parent_email, vars: {
        parent_name: @application.parent_first_name,
        child_name: @application.child_first_name,
        enrollment_fee: @application.effective_enrollment_fee.to_i,
        payment_link: @application.payment_selection_url,
        location_name: @location&.name
      })
    end

    mail(
      to: @application.parent_email,
      subject: "Next Steps: Enrollment Fee & Handbook"
    )
  end

  # Enrollment Invite
  # Sent to prospective families to invite them to apply
  def enrollment_invite(enrollment_application_id, enrollment_url)
    @application = EnrollmentApplication.includes(program: { program_classes: :location }).find(enrollment_application_id)
    @program = @application.program
    @recipient_name = @application.parent_first_name
    @enrollment_url = enrollment_url
    @location = @program.program_classes.first&.location
    @payment_plans = PaymentPlan.where(program: @program, active: true).order(:display_order)

    if (template = EmailTemplate.for('enrollment_invite'))
      return templated_mail(template, to: @application.parent_email, vars: {
        parent_name: @application.parent_first_name,
        program_name: @program.name,
        enrollment_link: @enrollment_url
      })
    end

    mail(
      to: @application.parent_email,
      subject: "You're Invited to Apply: #{@program.name}"
    )
  end

  # Enrollment Forms
  # Sent after fee is paid, contains forms for parent to sign
  def enrollment_forms(enrollment_application_id)
    @application = EnrollmentApplication.includes(:program, :program_enrollment).find(enrollment_application_id)
    @program = @application.program
    @enrollment = @application.program_enrollment
    @payment_plan = @enrollment&.enrollment_payment_plan&.payment_plan

    if (template = EmailTemplate.for('enrollment_forms'))
      return templated_mail(template, to: @application.parent_email, vars: {
        parent_name: @application.parent_first_name,
        child_name: @application.child_first_name,
        program_name: @program.name
      })
    end

    mail(
      to: @application.parent_email,
      subject: "Action Required: Enrollment Forms for #{@program.name}"
    )
  end

  # Email 4: Enrollment Confirmed (Bonus)
  # Sent after enrollment is complete
  def enrollment_confirmed(program_enrollment_id)
    @enrollment = ProgramEnrollment.includes(:child, :program, :enrollment_payment_plan).find(program_enrollment_id)
    @child = @enrollment.child
    @program = @enrollment.program
    @payment_plan = @enrollment.enrollment_payment_plan
    @family = @child.family

    if (template = EmailTemplate.for('enrollment_confirmed'))
      return templated_mail(template, to: @family.parents.pluck(:email), vars: {
        child_name: @child.first_name,
        program_name: @program.name
      })
    end

    mail(
      to: @family.parents.pluck(:email),
      subject: "Enrollment Confirmed for #{@child.first_name}! 🎉"
    )
  end
end
