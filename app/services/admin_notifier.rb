# Records an admin notification for a key parent-driven event and emails it to
# the school's connected mailbox. Called from the parent-facing flows, so it
# must never raise — a mail hiccup can't be allowed to break a parent
# scheduling a meeting, selecting a plan, or signing a form.
class AdminNotifier
  class << self
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
