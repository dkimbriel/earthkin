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
  #
  # The same daily run then charges autopay families whose installments fall
  # due today (AutopayCharger; AUTOPAY_DRY_RUN=1 logs without charging). Each
  # step runs even if the other fails.
  desc 'Email parents a reminder 3 days before each tuition installment, then charge autopay installments due today'
  task send_due: :environment do
    begin
      count = PaymentDueReminder.run
      puts "Sent #{count} payment reminder(s)."
    rescue StandardError => e
      warn "Payment reminders failed: #{e.class}: #{e.message}"
    end

    results = AutopayCharger.run
    puts "Autopay: #{results.to_h.inspect}"
  end
end
