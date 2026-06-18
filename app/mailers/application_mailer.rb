class ApplicationMailer < ActionMailer::Base
	default from: 'earthkinnatureschool@gmail.com'
	layout 'mailer'

	before_action :attach_logo

	private

	def attach_logo
		attachments.inline['logo.png'] = File.read(
			Rails.root.join('app/assets/images/Earthkin Nature School Logo H-W.png')
		)
	end
end
