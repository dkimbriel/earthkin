module Api
  class EnrollmentApplicationsController < BaseController
    skip_before_action :authenticate_user!, only: [:create] # Public application form
    skip_before_action :require_staff!, only: [:create]

    def index
      applications = EnrollmentApplication.includes(:program, :child, :family, events: :location)
                                          .order(created_at: :desc)

      # Filter by status if provided
      applications = applications.where(status: params[:status]) if params[:status].present?
      applications = applications.where(program_id: params[:program_id]) if params[:program_id].present?

      render json: applications.as_json(
        include: {
          program: { only: [:id, :name, :start_date, :end_date] },
          child: { only: [:id, :first_name, :last_name] },
          family: { only: [:id, :name] },
          events: {
            only: [:id, :event_type, :scheduled_at, :status, :proposed_dates],
            include: { location: { only: [:id, :name] } }
          }
        },
        methods: [:full_child_name, :full_parent_name]
      )
    end

    def counts
      counts = EnrollmentApplication.group(:status).count
      counts['all'] = counts.values.sum
      render json: counts
    end

    def show
      application = EnrollmentApplication.includes(
        :child, :family, :emails, :selected_payment_plan,
        program: :payment_plans,
        events: :location,
        program_enrollment: { enrollment_payment_plan: :payment_plan }
      ).find(params[:id])

      # Sort emails chronologically (newest first) by sent_at or created_at
      sorted_emails = application.emails.sort_by { |e| e.sent_at || e.created_at }.reverse

      # Get active payment plans for the program
      active_payment_plans = application.program.payment_plans.active

      render json: application.as_json(
        include: {
          program: {},
          child: {},
          family: { include: :parents },
          events: { include: :location },
          selected_payment_plan: {},
          program_enrollment: {
            include: {
              enrollment_payment_plan: {
                include: :payment_plan
              }
            }
          }
        },
        methods: [:full_child_name, :full_parent_name, :effective_enrollment_fee, :effective_tuition_amount]
      ).merge(
        emails: sorted_emails.as_json(
          only: [:id, :mailer_class, :email_type, :recipient, :subject, :status, :sent_at, :failed_at, :created_at, :html_body],
          methods: [:type_label, :status_color]
        ),
        payment_plans: active_payment_plans.as_json
      )
    end

    def create
      # Check if we're completing an existing invited application
      if params[:enrollment_application][:application_id].present?
        existing = EnrollmentApplication.find_by(
          id: params[:enrollment_application][:application_id],
          status: 'invited'
        )
        if existing
          existing.assign_attributes(application_params.except(:application_id))
          existing.status = 'submitted'
          existing.submitted_at = Time.current

          if existing.save
            return render json: existing, status: :ok
          else
            return render json: { errors: existing.errors.full_messages },
                          status: :unprocessable_entity
          end
        end
      end

      # Create new application if no valid existing application found
      application = EnrollmentApplication.new(application_params.except(:application_id))
      application.status = 'submitted'
      application.submitted_at = Time.current

      if application.save
        render json: application, status: :created
      else
        render json: { errors: application.errors.full_messages },
               status: :unprocessable_entity
      end
    end

    def update
      application = EnrollmentApplication.find(params[:id])
      application.update!(application_params)
      render json: application
    end

    # Custom actions for workflow transitions
    def mark_reviewed
      application = EnrollmentApplication.find(params[:id])
      service = EnrollmentWorkflowService.new(application)
      service.process_inquiry
      render json: application.reload
    end

    def decline
      application = EnrollmentApplication.find(params[:id])
      application.decline!(params[:notes])
      render json: application
    end

    def complete_meeting
      application = EnrollmentApplication.find(params[:id])

      # Find the scheduled/confirmed meet_and_greet event (not pending_selection)
      event = application.events.find_by(event_type: 'meet_and_greet', status: %w[scheduled confirmed])
      unless event
        render json: { error: 'No scheduled meeting found for this application' }, status: :unprocessable_entity
        return
      end

      service = EnrollmentWorkflowService.new(application)
      service.complete_meeting(event.id, outcome_notes: params[:outcome_notes])

      render json: application.reload
    end

    def request_fee
      application = EnrollmentApplication.find(params[:id])
      service = EnrollmentWorkflowService.new(application)
      service.request_enrollment_fee
      render json: application.reload
    end

    def process_fee_payment
      application = EnrollmentApplication.find(params[:id])

      # Allow recording a fee payment from any active status so an admin can
      # lock in a plan for a family who paid directly, without being forced
      # through the meet-and-greet flow first. Declined and enrolled
      # applications are terminal.
      if %w[declined enrolled].include?(application.status)
        render json: { error: 'Cannot process fee payment from current status' }, status: :unprocessable_entity
        return
      end

      service = EnrollmentWorkflowService.new(application)

      result = service.process_enrollment_fee_payment(
        payment_plan_id: params[:payment_plan_id],
        payment_method: params[:payment_method],
        payment_date: params[:payment_date],
        notes: params[:notes]
      )

      render json: {
        application: application.reload,
        enrollment: result[:enrollment],
        payment: result[:payment]
      }
    end

    def send_enrollment_forms
      application = EnrollmentApplication.find(params[:id])

      unless application.status == 'fee_paid'
        render json: { error: 'Cannot send enrollment forms from current status' }, status: :unprocessable_entity
        return
      end

      service = EnrollmentWorkflowService.new(application)
      service.send_enrollment_forms
      render json: application.reload
    end

    def confirm_enrollment
      application = EnrollmentApplication.find(params[:id])

      unless application.status == 'signing_docs'
        render json: { error: 'Cannot confirm enrollment from current status' }, status: :unprocessable_entity
        return
      end

      service = EnrollmentWorkflowService.new(application)
      service.confirm_enrollment
      render json: application.reload
    end

    def update_parent_email
      application = EnrollmentApplication.find(params[:id])
      old_email = application.parent_email

      if application.update(parent_email: params[:parent_email])
        render json: {
          application: application,
          message: "Email updated from #{old_email} to #{application.parent_email}"
        }
      else
        render json: { errors: application.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def update_custom_fees
      application = EnrollmentApplication.find(params[:id])

      # Allow setting to nil to reset to defaults
      custom_enrollment_fee = params[:custom_enrollment_fee].presence
      custom_tuition_amount = params[:custom_tuition_amount].presence

      if application.update(
        custom_enrollment_fee: custom_enrollment_fee,
        custom_tuition_amount: custom_tuition_amount
      )
        render json: {
          application: application.as_json(
            methods: [:effective_enrollment_fee, :effective_tuition_amount]
          ),
          message: 'Custom fees updated successfully'
        }
      else
        render json: { errors: application.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def send_email
      application = EnrollmentApplication.find(params[:id])
      email_type = params[:email_type]

      # Validate email type is allowed for current status
      unless can_send_email?(application, email_type)
        render json: { error: "Cannot send #{email_type} email for current status" }, status: :unprocessable_entity
        return
      end

      # Determine mailer args based on email type
      mailer_args = case email_type
      when 'meeting_scheduled'
        event = application.events.find_by(event_type: 'meet_and_greet', status: 'scheduled')
        return render json: { error: 'No meeting scheduled' }, status: :unprocessable_entity unless event
        [event.id]
      when 'enrollment_invite'
        enrollment_url = "#{request.base_url}/enroll?program_id=#{application.program_id}&application_id=#{application.id}"
        [application.id, enrollment_url]
      when 'enrollment_fee_request'
        [application.id]
      when 'enrollment_confirmed'
        return render json: { error: 'No enrollment yet' }, status: :unprocessable_entity unless application.program_enrollment
        [application.program_enrollment.id]
      else
        []
      end

      # Send the email
      email_service = EmailTrackingService.new(application)
      email_service.send_email('EnrollmentMailer', email_type, mailer_args)

      render json: { message: "#{email_type.titleize} email sent successfully" }
    end

    # Prefill the manual composer with a workflow email, tokens resolved for
    # this application, so an admin can edit before sending.
    def email_draft
      application = EnrollmentApplication.find(params[:id])
      email_type = params[:email_type].to_s

      EmailTemplate.ensure_defaults!
      template = EmailTemplate.for(email_type)
      return render json: { error: 'No template for this email type' }, status: :unprocessable_entity unless template

      vars = case email_type
      when 'enrollment_invite'
        enrollment_url = "#{request.base_url}/enroll?program_id=#{application.program_id}&application_id=#{application.id}"
        EnrollmentEmailVars.enrollment_invite(application, enrollment_url)
      when 'meeting_invite'
        event = application.events.where(event_type: 'meet_and_greet').order(:created_at).last
        return render json: { error: 'No meeting invite has been created yet' }, status: :unprocessable_entity unless event&.proposed_dates.present?
        EnrollmentEmailVars.meeting_invite(event, request.base_url)
      when 'meeting_scheduled'
        event = application.events.where(event_type: 'meet_and_greet').where.not(scheduled_at: nil).order(:created_at).last
        return render json: { error: 'No meeting scheduled yet' }, status: :unprocessable_entity unless event
        EnrollmentEmailVars.meeting_scheduled(event)
      when 'enrollment_fee_request'
        EnrollmentEmailVars.enrollment_fee_request(application)
      when 'enrollment_forms'
        EnrollmentEmailVars.enrollment_forms(application)
      when 'enrollment_confirmed'
        return render json: { error: 'No enrollment yet' }, status: :unprocessable_entity unless application.program_enrollment
        EnrollmentEmailVars.enrollment_confirmed(application.program_enrollment)
      else
        return render json: { error: 'Unsupported email type' }, status: :unprocessable_entity
      end

      render json: {
        recipient: application.parent_email,
        email_type: email_type,
        enrollment_application_id: application.id,
        subject: template.rendered_subject(vars),
        body: template.rendered_text(vars)
      }
    end

    def send_meeting_invite
      application = EnrollmentApplication.find(params[:id])

      # Validate application is in appropriate status
      unless ['submitted', 'reviewed'].include?(application.status)
        render json: { error: 'Cannot send meeting invite for current status' }, status: :unprocessable_entity
        return
      end

      # Validate required params
      unless params[:location_id].present? && params[:proposed_dates].present?
        render json: { error: 'location_id and proposed_dates are required' }, status: :unprocessable_entity
        return
      end

      # Parse proposed dates
      proposed_dates = params[:proposed_dates].map { |d| Time.zone.parse(d) }

      if proposed_dates.length < 2 || proposed_dates.length > 5
        render json: { error: 'Please provide 2-5 date options' }, status: :unprocessable_entity
        return
      end

      service = EnrollmentWorkflowService.new(application)
      event = service.send_meeting_invite(
        location_id: params[:location_id],
        proposed_dates: proposed_dates,
        base_url: request.base_url,
        notes: params[:notes]
      )

      render json: {
        message: 'Meeting invite email sent successfully',
        event: event.as_json(include: :location)
      }
    end

    private

    def can_send_email?(application, email_type)
      case email_type
      when 'enrollment_invite'
        application.status == 'invited'
      when 'meeting_scheduled'
        # Can send if meeting is scheduled (not pending_selection) and status allows
        ['reviewed', 'meeting_scheduled', 'meeting_completed', 'fee_requested', 'fee_paid', 'enrolled'].include?(application.status) &&
          application.events.exists?(event_type: 'meet_and_greet', status: 'scheduled')
      when 'enrollment_fee_request'
        # Can send if meeting completed or later
        ['meeting_completed', 'fee_requested', 'fee_paid', 'enrolled'].include?(application.status)
      when 'enrollment_confirmed'
        # Can send if enrolled
        application.status == 'enrolled'
      else
        false
      end
    end

    private

    def application_params
      params.require(:enrollment_application).permit(
        :program_id, :family_id, :child_id, :application_id,
        :parent_first_name, :parent_last_name, :parent_email, :parent_phone,
        :parent2_first_name, :parent2_last_name, :parent2_email, :parent2_phone,
        :child_first_name, :child_last_name, :child_date_of_birth,
        :child_race_ethnicity,
        :why_interested, :child_description, :special_needs,
        :dietary_restrictions, :previous_school_experience, :parent_expectations,
        :is_local, :local_area, :referral_source,
        :admin_notes,
        :custom_enrollment_fee, :custom_tuition_amount,
        agreements: {}
      )
    end
  end
end
