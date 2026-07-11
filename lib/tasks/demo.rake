# Development helpers for demo data.
namespace :demo do
	desc 'Reset the demo parent and issue fresh unsigned enrollment forms (dev only)'
	task forms: :environment do
		abort 'demo:forms is for development only' unless Rails.env.development?

		password = 'preview123'

		parent_user = User.find_or_initialize_by(email: 'parent.demo@earthkin.test')
		parent_user.assign_attributes(role: 'parent', password: password, password_confirmation: password)
		parent_user.save!

		parent = parent_user.parent
		if parent.nil?
			family = Family.find_or_create_by!(name: 'Demo Family')
			parent = family.parents.find_or_create_by!(email: 'parent.demo@earthkin.test') do |p|
				p.first_name = 'Demo'
				p.last_name = 'Parent'
			end
			parent.update!(user: parent_user)
		end

		family = parent.family
		child = family.children.first || family.children.create!(first_name: 'Demo', last_name: 'Child')

		# Fresh, unsigned copies of all four forms every run.
		child.enrollment_form_signatures.destroy_all
		FormTemplate.ensure_defaults!.each do |form|
			EnrollmentFormSignature.find_or_create_by!(child: child, form_template: form, enrollment_application: nil)
		end

		puts "Demo forms reset for #{child.full_name} (#{family.name})"
		puts ''
		puts '  Login:    parent.demo@earthkin.test'
		puts "  Password: #{password}"
		puts '  URL:      http://localhost:3000/forms'
		puts ''
		puts "  Pending forms: #{child.enrollment_form_signatures.pending.count}"
	end
end
