# frozen_string_literal: true

namespace :payment_reminders do
  # Emails parents a reminder for every tuition installment due today.
  #
  # Runs once a day via Heroku Scheduler. Add a daily job (any time — the task
  # keys off "today"):
  #
  #     bundle exec rake payment_reminders:send_due
  #
  # Safe to run more than once a day: reminders are idempotent per installment
  # invoice, so a duplicate run won't double-email families.
  desc 'Email parents a reminder for each tuition installment due today'
  task send_due: :environment do
    count = PaymentDueReminder.run
    puts "Sent #{count} payment reminder(s)."
  end
end
