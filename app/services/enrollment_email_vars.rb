# Builds the {{token}} values for workflow email templates. Used by the
# mailers when rendering and by the email-draft endpoint when prefilling
# the manual composer.
class EnrollmentEmailVars
  class << self
    # Best-effort vars for the manual email composer. Unlike the per-type
    # methods below (used by the mailers, which only fire once their data
    # exists), this never raises: when a stage's data isn't in place yet it
    # falls back to the always-available application tokens, and the draft
    # endpoint leaves a [placeholder] for whatever's still missing. Returns
    # nil for an unknown email type.
    def draft(application, email_type, enrollment_url: nil, base_url: nil)
      case email_type
      when 'enrollment_invite'
        enrollment_invite(application, enrollment_url)
      when 'enrollment_fee_request'
        enrollment_fee_request(application)
      when 'meeting_invite'
        event = latest_meet_and_greet(application)
        event&.proposed_dates.present? ? meeting_invite(event, base_url) : base_application_vars(application)
      when 'meeting_scheduled'
        event = application.events.where(event_type: 'meet_and_greet').where.not(scheduled_at: nil).order(:created_at).last
        event ? meeting_scheduled(event) : base_application_vars(application)
      when 'enrollment_confirmed'
        application.program_enrollment ? enrollment_confirmed(application.program_enrollment) : base_application_vars(application)
      end
    end

    def enrollment_invite(application, enrollment_url)
      program = application.program
      tuition = application.effective_tuition_amount || program.tuition_amount
      {
        parent_name: application.parent_first_name,
        program_name: program.name,
        program_dates: format_date_range(program),
        class_days: program.class_days.presence || 'select days',
        time_range: program.formatted_time_range.presence || 'times TBD',
        tuition: delimited(tuition.to_i),
        enrollment_fee: delimited(application.effective_enrollment_fee.to_i),
        enrollment_link: enrollment_url
      }
    end

    def meeting_invite(event, base_url)
      application = event.eventable
      program = application.program
      tuition = application.effective_tuition_amount || program.tuition_amount
      {
        parent_name: application.parent_first_name,
        child_name: application.child_first_name,
        program_name: program.name,
        program_dates: format_date_range(program),
        class_days: program.class_days.presence || 'select days',
        time_range: program.formatted_time_range.presence || 'times TBD',
        tuition: delimited(tuition.to_i),
        enrollment_fee: delimited(application.effective_enrollment_fee.to_i),
        location_name: event.location&.name || 'Forest Hill Park',
        date_options: date_options(event, base_url)
      }
    end

    def meeting_scheduled(event)
      application = event.eventable
      {
        parent_name: application.parent_first_name,
        child_name: application.child_first_name,
        program_name: application.program.name,
        meeting_datetime: event.scheduled_at&.strftime('%B %d at %I:%M %p'),
        location_name: event.location&.name || 'Forest Hill Park',
        location_address: event.location&.address,
        handbook_url: ENV['FAMILY_HANDBOOK_URL']
      }
    end

    def enrollment_fee_request(application)
      meeting_event = application.events.find_by(event_type: 'meet_and_greet', status: 'completed')
      location = meeting_event&.location || application.program.program_classes.first&.location
      {
        parent_name: application.parent_first_name,
        child_name: application.child_first_name,
        enrollment_fee: delimited(application.effective_enrollment_fee.to_i),
        payment_link: application.payment_selection_url,
        location_name: location&.name || 'Forest Hill Park',
        handbook_url: ENV['FAMILY_HANDBOOK_URL']
      }
    end

    def enrollment_forms(application)
      {
        parent_name: application.parent_first_name,
        child_name: application.child_first_name,
        program_name: application.program.name,
        login_url: portal_url
      }
    end

    # Same forms email, but sourced from a program enrollment + parent instead
    # of an application (used for manually-added families that never went
    # through the application queue).
    def enrollment_forms_for_enrollment(enrollment, parent)
      {
        parent_name: parent.first_name,
        child_name: enrollment.child.first_name,
        program_name: enrollment.program.name,
        login_url: portal_url
      }
    end

    def enrollment_confirmed(enrollment)
      program = enrollment.program
      {
        child_name: enrollment.child.first_name,
        program_name: program.name,
        program_dates: format_date_range(program),
        class_days: program.class_days.presence || 'Days TBD',
        payment_plan_summary: payment_plan_summary(enrollment.enrollment_payment_plan)
      }
    end

    private

    # Application-level tokens that are always resolvable regardless of stage.
    # Used as the draft fallback when a stage's own data (a scheduled meeting,
    # an enrollment, etc.) doesn't exist yet.
    def base_application_vars(application)
      program = application.program
      tuition = application.effective_tuition_amount || program.tuition_amount
      {
        parent_name: application.parent_first_name,
        child_name: application.child_first_name,
        program_name: program.name,
        program_dates: format_date_range(program),
        class_days: program.class_days.presence || 'select days',
        time_range: program.formatted_time_range.presence || 'times TBD',
        tuition: delimited(tuition.to_i),
        enrollment_fee: delimited(application.effective_enrollment_fee.to_i),
        payment_link: application.payment_selection_url,
        handbook_url: ENV['FAMILY_HANDBOOK_URL']
      }
    end

    def latest_meet_and_greet(application)
      application.events.where(event_type: 'meet_and_greet').order(:created_at).last
    end

    # Trusted HTML: one styled "button" link per proposed meeting time. Marked
    # html_safe so EmailTemplate#rendered_html emits real buttons in the sent
    # email; the manual composer (rendered_text) turns these back into plain
    # "date — url" lines. Both the label and href are escaped defensively.
    def date_options(event, base_url)
      event.proposed_dates_as_times.map do |time|
        label = time.strftime('%A, %B %-d at %I:%M %p')
        href = "#{base_url}/meetings/#{event.confirmation_token}/confirm?date=#{time.to_i}"
        %(<a href="#{ERB::Util.html_escape(href)}" style="display:inline-block;padding:12px 24px;margin:4px 0;) +
          %(background-color:#4a7c59;color:#ffffff;text-decoration:none;border-radius:6px;font-weight:bold;">) +
          %(#{ERB::Util.html_escape(label)}</a>)
      end.join('<br>').html_safe
    end

    def format_date_range(program)
      return 'dates TBD' unless program.start_date && program.end_date

      "#{program.start_date.strftime('%b %d, %Y')}–#{program.end_date.strftime('%b %d, %Y')}"
    end

    def payment_plan_summary(enrollment_payment_plan)
      return 'Your selected payment plan details are available in your parent portal.' unless enrollment_payment_plan

      plan = enrollment_payment_plan.payment_plan
      installment = (enrollment_payment_plan.total_amount / plan.installment_count).round(2)
      [
        plan.name,
        "Total Tuition: $#{delimited(enrollment_payment_plan.total_amount.to_i)}",
        "Enrollment Fee: $#{delimited(enrollment_payment_plan.enrollment_fee.to_i)} (paid)",
        "#{plan.installment_count} payment(s) of $#{delimited(installment)}"
      ].join("\n")
    end

    def portal_url
      Rails.application.routes.url_helpers.root_url(**(ActionMailer::Base.default_url_options || {}))
    end

    def delimited(value)
      ActiveSupport::NumberHelper.number_to_delimited(value)
    end
  end
end
