class ParentMailer < ApplicationMailer
  def welcome_email(parent_id, temporary_password)
    @parent = Parent.find(parent_id)
    @temporary_password = temporary_password
    @login_url = root_url

    if (template = EmailTemplate.for('welcome_email'))
      return templated_mail(template, to: @parent.email, vars: {
        parent_name: @parent.first_name,
        email: @parent.email,
        password: @temporary_password,
        login_url: @login_url
      })
    end

    mail(
      to: @parent.email,
      subject: "Welcome to Earthkin Nature School - Your Account is Ready!"
    )
  end

  def application_status_update(parent_id, enrollment_application_id)
    @parent = Parent.find(parent_id)
    @application = EnrollmentApplication.find(enrollment_application_id)
    @login_url = root_url

    if (template = EmailTemplate.for('application_status_update'))
      return templated_mail(template, to: @parent.email, vars: {
        parent_name: @parent.first_name,
        status: @application.status.titleize,
        login_url: @login_url
      })
    end

    mail(
      to: @parent.email,
      subject: "Update on Your Enrollment Application"
    )
  end
end
