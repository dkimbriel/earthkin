class EnrollmentWorkflowService
  def initialize(enrollment_application)
    @application = enrollment_application
  end

  def process_inquiry
    @application.mark_reviewed!
    # Could add admin notification here
    @application
  end

  def schedule_meeting(location_id:, scheduled_at:, notes: nil)
    event = @application.events.create!(
      event_type: 'meet_and_greet',
      location_id: location_id,
      scheduled_at: scheduled_at,
      notes: notes,
      title: "Meet & Greet: #{@application.full_child_name}",
      description: "Meet and greet for #{@application.full_parent_name} and #{@application.full_child_name}"
    )

    @application.schedule_meeting!

    # Send tracked email
    email_service = EmailTrackingService.new(@application)
    email_service.send_email('EnrollmentMailer', 'meeting_scheduled', [event.id], { event_id: event.id })

    event
  end

  def send_meeting_invite(location_id:, proposed_dates:, base_url:, notes: nil)
    # Create event with pending_selection status - parent will choose the date
    event = @application.events.create!(
      event_type: 'meet_and_greet',
      location_id: location_id,
      status: 'pending_selection',
      proposed_dates: proposed_dates,
      notes: notes,
      title: "Meet & Greet: #{@application.full_child_name}",
      description: "Meet and greet for #{@application.full_parent_name} and #{@application.full_child_name}"
    )

    # Send the meeting invite email
    email_service = EmailTrackingService.new(@application)
    email_service.send_email('EnrollmentMailer', 'meeting_invite', [event.id, base_url], { event_id: event.id })

    event
  end

  def complete_meeting(event_id = nil, outcome_notes: nil)
    # event_id is nil when an admin marks the meeting complete without ever
    # scheduling one (skipping the meet-and-greet); just advance the app.
    event = event_id && @application.events.find(event_id)
    event&.complete!(outcome_notes)
    @application.complete_meeting!

    # Optionally auto-request enrollment fee
    request_enrollment_fee if auto_advance?

    event
  end

  def request_enrollment_fee
    @application.request_enrollment_fee!
    email_service = EmailTrackingService.new(@application)
    email_service.send_email('EnrollmentMailer', 'enrollment_fee_request', [@application.id])
    @application
  end

  def process_enrollment_fee_payment(payment_plan_id:, payment_method:, payment_date: nil, payment_start_date: nil, notes: nil)
    ActiveRecord::Base.transaction do
      # 1. Find or create family and child records
      family = find_or_create_family
      child = find_or_create_child(family)

      # 2. Update application with linked records
      @application.update!(family: family, child: child)

      # 3. Create or update enrollment
      enrollment = find_or_create_enrollment(child)

      # 4. Link application to enrollment
      @application.update!(program_enrollment: enrollment)

      # 5. Create payment plan selection with schedule based on start date
      payment_plan = PaymentPlan.find(payment_plan_id)
      @application.update!(selected_payment_plan: payment_plan)
      start_date = payment_start_date || @application.program.start_date || Date.current
      enrollment_payment_plan = create_enrollment_payment_plan(enrollment, payment_plan, start_date)

      # 6. Record enrollment fee payment
      payment = enrollment_payment_plan.payments.create!(
        program_enrollment: enrollment,
        payment_type: 'enrollment_fee',
        amount: enrollment_payment_plan.enrollment_fee,
        payment_method: payment_method,
        payment_date: payment_date || Date.current,
        status: 'completed',
        notes: notes
      )

      # 7. Mark enrollment fee as paid
      enrollment_payment_plan.mark_enrollment_fee_paid!
      @application.mark_fee_paid!
      enrollment.advance_workflow_to!('fee_paid')

      { enrollment: enrollment, payment: payment, enrollment_payment_plan: enrollment_payment_plan }
    end
  end

  def send_enrollment_forms
    ActiveRecord::Base.transaction do
      @application.send_enrollment_forms!
      @application.program_enrollment&.advance_workflow_to!('signing_docs')

      create_pending_form_signatures

      email_service = EmailTrackingService.new(@application)
      email_service.send_email('EnrollmentMailer', 'enrollment_forms', [@application.id])
    end
    @application
  end

  def confirm_enrollment
    ActiveRecord::Base.transaction do
      @application.enroll!
      @application.program_enrollment&.advance_workflow_to!('enrolled')
      @application.program_enrollment&.update!(status: 'confirmed')

      email_service = EmailTrackingService.new(@application)
      # The confirmed mailer takes the program enrollment, not the application
      email_service.send_email('EnrollmentMailer', 'enrollment_confirmed', [@application.program_enrollment.id]) if @application.program_enrollment
    end
    @application
  end

  private

  # Issue the four standard enrollment forms for e-signature in the parent
  # portal. Skipped when the application has no linked child yet.
  def create_pending_form_signatures
    return unless @application.child

    FormTemplate.ensure_defaults!.each do |form|
      EnrollmentFormSignature.find_or_create_by!(
        child: @application.child,
        form_template: form,
        enrollment_application: @application
      )
    end
  end

  def find_or_create_family
    # Try to find existing parent by email
    parent = Parent.find_by(email: @application.parent_email)

    if parent
      # Create user account if parent doesn't have one yet
      parent.create_user_account! unless parent.user
      return parent.family
    end

    # Create new family
    Family.create!(
      name: "#{@application.parent_last_name} Family"
    ).tap do |family|
      # Create the parent record
      parent = family.parents.create!(
        first_name: @application.parent_first_name,
        last_name: @application.parent_last_name,
        email: @application.parent_email,
        phone: @application.parent_phone
      )

      # Create user account for the parent so they can log in
      parent.create_user_account!
    end
  end

  def find_or_create_child(family)
    # Try to find existing child in the family
    child = family.children.find_by(
      first_name: @application.child_first_name,
      last_name: @application.child_last_name
    )

    return child if child

    # Create new child
    family.children.create!(
      first_name: @application.child_first_name,
      last_name: @application.child_last_name
    )
  end

  def find_or_create_enrollment(child)
    # Check if enrollment already exists for this child and program
    enrollment = ProgramEnrollment.find_by(
      child: child,
      program: @application.program
    )

    return enrollment if enrollment

    # Create new enrollment (rate_per_class no longer required - using payment plans)
    ProgramEnrollment.create!(
      child: child,
      program: @application.program,
      enrollment_application: @application,
      status: 'pending',
      workflow_status: 'fee_paid'
    )
  end

  def create_enrollment_payment_plan(enrollment, payment_plan, start_date)
    # Create the payment plan selection for this enrollment
    # Use application's effective amounts (custom overrides or defaults)
    enrollment.create_enrollment_payment_plan!(
      payment_plan: payment_plan,
      total_amount: @application.custom_tuition_amount || payment_plan.total_amount,
      enrollment_fee: @application.effective_enrollment_fee,
      installments: build_installment_snapshot(payment_plan, start_date)
    )
  end

  def build_installment_snapshot(payment_plan, start_date)
    # Use payment plan's generate_schedule method to create enrollment-specific installments
    payment_plan.generate_schedule(start_date).map do |installment|
      {
        due_date: installment['due_date'],
        amount: installment['amount'],
        status: 'pending',
        paid_at: nil
      }
    end
  end

  def auto_advance?
    # Auto-advance from meeting_completed to fee_requested and send fee email
    true
  end
end
