namespace :admin do
  desc "Create initial super admin user"
  task create_super_admin: :environment do
    require "io/console"

    puts "Creating super admin user..."
    puts

    print "Email: "
    email = $stdin.gets.chomp

    print "Password: "
    password = $stdin.noecho(&:gets).chomp
    puts

    print "Confirm password: "
    password_confirmation = $stdin.noecho(&:gets).chomp
    puts

    if password != password_confirmation
      puts "Error: Passwords do not match"
      exit 1
    end

    if password.length < 6
      puts "Error: Password must be at least 6 characters"
      exit 1
    end

    user = User.new(
      email: email,
      password: password,
      password_confirmation: password_confirmation,
      super_admin: true
    )

    if user.save
      puts
      puts "Super admin user created successfully!"
      puts "Email: #{email}"
    else
      puts
      puts "Error creating user:"
      user.errors.full_messages.each do |message|
        puts "  - #{message}"
      end
      exit 1
    end
  end
end
