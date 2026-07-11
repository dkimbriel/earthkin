class ApplicationMailer < ActionMailer::Base
	default from: 'earthkinnatureschool@gmail.com'
	layout 'mailer'

	before_action :attach_logo

	private

	# Render an admin-edited EmailTemplate instead of the built-in ERB view.
	def templated_mail(template, to:, vars: {})
		body_html = template.rendered_html(vars)
		mail(to: to, subject: template.rendered_subject(vars)) do |format|
			format.html { render html: body_html.html_safe, layout: 'mailer' }
		end
	end

	def attach_logo
		attachments.inline['logo.png'] = File.read(
			Rails.root.join('app/assets/images/Earthkin Nature School Logo H-W.png')
		)
	end
end
