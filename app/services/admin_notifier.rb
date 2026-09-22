# Records an admin notification for a key parent-driven event and emails it to
# the school's connected mailbox. Called from the parent-facing flows, so it
# must never raise — a mail hiccup can't be allowed to break a parent
# scheduling a meeting, selecting a plan, or signing a form.
class AdminNotifier
  class << self
    # Fired when a prospective family submits an enrollment application — the
    # first heads-up to staff that there's a new lead to review.
    def application_submitted(application)
      notify(
        event_type: 'application_submitted',
        title: "New application — #{application.full_child_name}",
        body: "#{application.full_parent_name} submitted an enrollment application for #{application.full_child_name}. Review it when you're ready.",
        enrollment_application: application
      )
    end

    def meeting_scheduled(application, event)
      when_time = event.scheduled_at&.strftime('%A, %B %-d at %-I:%M %p')
      location = event.location&.name
      details = [when_time, location].compact.join(' at ')
      notify(
        event_type: 'meeting_scheduled',
        title: "Meet & greet scheduled — #{application.full_child_name}",
        body: "#{application.full_parent_name} picked a meet & greet time#{details.present? ? ": #{details}" : ''}.",
        enrollment_application: application
      )
    end

    def payment_plan_selected(application, payment_plan)
      notify(
        event_type: 'payment_plan_selected',
        title: "Payment plan selected — #{application.full_child_name}",
        body: "#{application.full_parent_name} selected the #{payment_plan.name} plan. Record their enrollment fee to lock it in.",
        enrollment_application: application
      )
    end

    # Fired when a Stripe checkout completes and we record the payment (via the
    # webhook) — the school's cue that money actually landed.
    def payment_completed(payment)
      enrollment = payment.program_enrollment
      child_name = enrollment&.child&.full_name.presence || 'a family'
      amount = format('%.2f', payment.amount.to_d)
      label = case payment.payment_type
              when 'enrollment_fee' then 'enrollment fee'
              when 'tuition'
                payment.installment_number ? "tuition installment ##{payment.installment_number}" : 'tuition payment'
              else 'payment'
              end
      notify(
        event_type: 'payment_completed',
        title: "Payment received — #{child_name} ($#{amount})",
        body: "A #{label} of $#{amount} was paid via Stripe for #{child_name}.",
        enrollment_application: enrollment&.enrollment_application
      )
    end

    # Fired the first time a parent signs in to the portal — a cue that the
    # family is set up and their enrollment forms can be issued.
    def family_first_login(user)
      parent = user.parent
      name = parent&.full_name.presence || user.email
      application = parent&.family&.enrollment_applications&.order(created_at: :desc)&.first
      notify(
        event_type: 'family_first_login',
        title: "Family logged in — #{name}",
        body: "#{name} signed in to the portal for the first time. Issue their enrollment forms when you're ready.",
        enrollment_application: application
      )
    end

    # Fired when an enrollment matches a previously-deleted family and we
    # restore + reuse it rather than creating a duplicate — a heads-up to review.
    def family_restored_from_deletion(parent)
      family = parent.family
      application = family&.enrollment_applications&.order(created_at: :desc)&.first
      notify(
        event_type: 'family_restored_from_deletion',
        title: "Deleted family re-activated — #{parent.full_name}",
        body: "#{parent.full_name} (#{parent.email}) matched a previously-deleted account, so it was restored and linked instead of duplicated. Review the family to make sure everything looks right.",
        enrollment_application: application
      )
    end

    def form_signed(signature)
      application = signature.enrollment_application
      notify(
        event_type: 'form_signed',
        title: "Enrollment form signed — #{signature.child.full_name}",
        body: "#{signature.signed_by_name} signed the #{signature.form_template.name}.",
        enrollment_application: application
      )
    end

    # Fired when an employee acknowledges a staff document (a warning or a
    # termination letter) in the portal, so the director knows it landed and
    # can counter-sign it.
    def staff_document_signed(document)
      comments = document.employee_comments.present? ? ' They left written comments.' : ''
      notify(
        event_type: 'staff_document_signed',
        title: "Staff document signed: #{document.teacher.full_name}",
        body: "#{document.employee_signed_by_name} acknowledged the #{document.title}.#{comments} It is ready for your counter-signature."
      )
    end

    # Fired when an outgoing email failed to deliver. EmailTrackingService
    # records the failure and carries on, so without this the only trace is a
    # log line and a status chip nobody is looking at.
    def email_delivery_failed(email)
      application = email.emailable.is_a?(EnrollmentApplication) ? email.emailable : nil
      notify(
        event_type: 'email_delivery_failed',
        title: "Email failed to send to #{email.recipient}",
        body: "The #{email.type_label.downcase} email to #{email.recipient} did not go out " \
              "(#{EmailOutcome.first_line(email.error_message)}). They have not heard from us. " \
              'Check the Communications tab and re-send once the problem is fixed.',
        enrollment_application: application
      )
    end

    # The mailbox alerts are delivered to: the connected Gmail with a "+alerts"
    # sub-address so it threads/labels cleanly instead of colliding with mail
    # the account sends to itself. Nil when no mailbox is connected.
    def alert_address
      email = GmailIntegration.current&.email
      return nil if email.blank?

      local, domain = email.split('@', 2)
      return email if domain.blank?

      suffix = ENV.fetch('ADMIN_ALERT_SUFFIX', 'alerts')
      "#{local}+#{suffix}@#{domain}"
    end

    private

    def notify(event_type:, title:, body:, enrollment_application: nil)
      notification = Notification.create!(
        event_type: event_type,
        title: title,
        body: body,
        enrollment_application: enrollment_application
      )
      deliver_email(notification)
      notification
    rescue StandardError => e
      Rails.logger.error("AdminNotifier failed for #{event_type}: #{e.class} #{e.message}")
      nil
    end

    def deliver_email(notification)
      return if alert_address.blank?

      AdminNotificationMailer.alert(notification.id).deliver_now
    rescue StandardError => e
      # In-app notification already saved; a mail failure must not surface to
      # the parent whose action triggered it.
      Rails.logger.error("AdminNotifier email failed: #{e.class} #{e.message}")
    end
  end
end
