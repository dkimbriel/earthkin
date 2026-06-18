# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Update existing programs with schedule fields
puts "Updating programs with schedule fields..."

Program.find_each do |program|
  program.update!(
    enrollment_fee: program.enrollment_fee || 150.00,
    class_days: program.class_days || 'Monday & Wednesday',
    start_time: program.start_time || Time.zone.parse('09:00'),
    end_time: program.end_time || Time.zone.parse('12:00')
  )
  puts "  Updated: #{program.name}"
end

puts "✓ Programs updated with schedule fields!"
puts ""

# Create payment plans for each program
puts "Creating payment plans for existing programs..."

Program.find_each do |program|
  # Skip if payment plans already exist for this program
  next if program.payment_plans.any?

  puts "  Creating payment plans for: #{program.name}"

  PaymentPlan.create!([
    {
      program: program,
      name: 'Full Payment',
      description: 'Pay in full by August 1',
      installment_count: 1,
      total_amount: 2800.00,
      installment_schedule: [{ month: 8, day: 1, amount: 2800 }],
      display_order: 1,
      active: true
    },
    {
      program: program,
      name: 'Semester Payments',
      description: 'Two payments (Aug 1, Jan 1)',
      installment_count: 2,
      total_amount: 2800.00,
      installment_schedule: [
        { month: 8, day: 1, amount: 1400 },
        { month: 1, day: 1, amount: 1400 }
      ],
      display_order: 2,
      active: true
    },
    {
      program: program,
      name: 'Quarterly Payments',
      description: 'Four quarterly payments',
      installment_count: 4,
      total_amount: 2800.00,
      installment_schedule: [
        { month: 8, day: 1, amount: 700 },
        { month: 10, day: 1, amount: 700 },
        { month: 1, day: 1, amount: 700 },
        { month: 4, day: 1, amount: 700 }
      ],
      display_order: 3,
      active: true
    },
    {
      program: program,
      name: 'Monthly Payments',
      description: '10 monthly payments starting August 1',
      installment_count: 10,
      total_amount: 2800.00,
      installment_schedule: [
        { month: 8, day: 1, amount: 280 },
        { month: 9, day: 1, amount: 280 },
        { month: 10, day: 1, amount: 280 },
        { month: 11, day: 1, amount: 280 },
        { month: 12, day: 1, amount: 280 },
        { month: 1, day: 1, amount: 280 },
        { month: 2, day: 1, amount: 280 },
        { month: 3, day: 1, amount: 280 },
        { month: 4, day: 1, amount: 280 },
        { month: 5, day: 1, amount: 280 }
      ],
      display_order: 4,
      active: true
    }
  ])
end

puts "✓ Payment plans created successfully!"
