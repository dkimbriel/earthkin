# frozen_string_literal: true

# Production bootstrap seed: a super-admin user and the program catalog
# (program, location, teachers, classes, payment plans, and their links).
#
# Idempotent — safe to run repeatedly; existing records are matched by natural
# key and not duplicated.
#
# Run with:  SEED_ADMIN_PASSWORD=… rails db:seed
#   (on Heroku: heroku config:set SEED_ADMIN_PASSWORD=… && heroku run rails db:seed)

ActiveRecord::Base.transaction do
	# --- Super-admin user -----------------------------------------------------
	admin_email = ENV.fetch('SEED_ADMIN_EMAIL', 'earthkinnatureschool@gmail.com')
	admin = User.find_or_initialize_by(email: admin_email)
	if admin.new_record?
		password = ENV['SEED_ADMIN_PASSWORD']
		raise "Set SEED_ADMIN_PASSWORD to create the super-admin (#{admin_email})" if password.blank?

		admin.password = password
	end
	admin.super_admin = true
	admin.save!
	puts "✓ super-admin: #{admin.email}"

	# --- Location -------------------------------------------------------------
	location = Location.find_or_create_by!(name: 'Forest Hill Park') do |l|
		l.address = '4021 Forest Hill Avenue, Richmond, VA 23225'
		l.notes   = 'Lovely city park'
	end

	# --- Teachers -------------------------------------------------------------
	teachers_data = [
		{ first_name: 'Sidney', last_name: 'Gary',     email: 'sidney@teacher.com', phone: '1238401941', bio: 'She teaches good' },
		{ first_name: 'Cidney', last_name: 'Oleniacz', email: 'cidney@teach.com',   phone: '8041238593', bio: 'I teach too' },
		{ first_name: 'David',  last_name: 'Bernier',  email: 'david@gmail.com',    phone: '1234567890', bio: '' }
	]
	teachers_by_email = teachers_data.each_with_object({}) do |attrs, memo|
		teacher = Teacher.find_or_create_by!(email: attrs[:email]) do |t|
			t.assign_attributes(attrs.except(:email))
		end
		memo[attrs[:email]] = teacher
	end

	# --- Program --------------------------------------------------------------
	program = Program.find_or_create_by!(name: '2026 - 2027 Nature Preschool Program') do |p|
		p.description    = ''
		p.start_date     = Date.new(2026, 8, 24)
		p.end_date       = Date.new(2027, 6, 2)
		p.capacity       = 12
		p.enrollment_fee = 150.0
		p.class_days     = 'Monday & Wednesday'
		p.start_time     = '09:00'
		p.end_time       = '12:00'
	end
	puts "✓ program: #{program.name}"

	# --- Program classes ------------------------------------------------------
	classes_data = [
		{ name: 'Class 1', date: Date.new(2025, 11, 7),  start_time: '03:00', end_time: '07:00', location: 'Ravine' },
		{ name: 'Class 2', date: Date.new(2025, 12, 5),  start_time: '03:00', end_time: '07:00', location: 'Ravine' },
		{ name: 'Class 3', date: Date.new(2025, 12, 19), start_time: '03:00', end_time: '07:00', location: nil }
	]
	classes_data.each do |attrs|
		program.program_classes.find_or_create_by!(name: attrs[:name]) do |c|
			c.date        = attrs[:date]
			c.start_time  = attrs[:start_time]
			c.end_time    = attrs[:end_time]
			c[:location]  = attrs[:location] # string column, shadowed by belongs_to :location
			c.location_id = location.id
		end
	end

	# --- Payment plans --------------------------------------------------------
	plans_data = [
		{ name: 'Full Payment', description: 'Pay in full by August 1', installment_count: 1, display_order: 1,
		  installment_schedule: [{ 'month' => 8, 'day' => 1, 'amount' => 2800 }] },
		{ name: 'Semester Payments', description: 'Two payments (Aug 1, Jan 1)', installment_count: 2, display_order: 2,
		  installment_schedule: [{ 'month' => 8, 'day' => 1, 'amount' => 1400 }, { 'month' => 1, 'day' => 1, 'amount' => 1400 }] },
		{ name: 'Quarterly Payments', description: 'Four quarterly payments', installment_count: 4, display_order: 3,
		  installment_schedule: [{ 'month' => 8, 'day' => 1, 'amount' => 700 }, { 'month' => 10, 'day' => 1, 'amount' => 700 }, { 'month' => 1, 'day' => 1, 'amount' => 700 }, { 'month' => 4, 'day' => 1, 'amount' => 700 }] },
		{ name: 'Monthly Payments', description: '10 monthly payments starting August 1', installment_count: 10, display_order: 4,
		  installment_schedule: [8, 9, 10, 11, 12, 1, 2, 3, 4, 5].map { |m| { 'month' => m, 'day' => 1, 'amount' => 280 } } }
	]
	plans_data.each do |attrs|
		program.payment_plans.find_or_create_by!(name: attrs[:name]) do |pp|
			pp.assign_attributes(attrs.except(:name))
			pp.total_amount = 2800.0
			pp.active = true
		end
	end

	# --- Program ↔ teacher links ---------------------------------------------
	%w[sidney@teacher.com cidney@teach.com].each do |email|
		ProgramTeacher.find_or_create_by!(program: program, teacher: teachers_by_email[email])
	end

	# --- Program class ↔ teacher links ---------------------------------------
	class2 = program.program_classes.find_by!(name: 'Class 2')
	ProgramClassTeacher.find_or_create_by!(program_class: class2, teacher: teachers_by_email['sidney@teacher.com'])

	puts '✓ program catalog seeded'
end
