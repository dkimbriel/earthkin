# frozen_string_literal: true

# Week-by-week cash for the dashboard: what came in and what's due.
#
# The window is Monday-start weeks: WEEKS_BACK before this one, this week, and
# enough after to make WEEKS_AHEAD including this week. Each week has:
#   collected   - completed payments (tuition, fees, anything) by payment_date
#   outstanding - unpaid money due that week:
#                   pending tuition installments by due date,
#                   pending invoices not tied to an installment by payment_date,
#                   per-class rates for upcoming classes of legacy enrollments
#                   that have no payment plan
# Outstanding in a past week is overdue. Invoices tied to an installment (the
# reminder's and Stripe's) aren't counted on top of the installment itself.
class WeeklyCashForecast
  WEEKS_BACK = 4
  WEEKS_AHEAD = 12

  def initialize(today: Date.current)
    @today = today
    @this_week = today.beginning_of_week(:monday)
    @first_week = @this_week - WEEKS_BACK.weeks
    @last_day = @this_week + (WEEKS_AHEAD - 1).weeks + 6.days
  end

  def call
    lines = collected_lines + outstanding_lines

    weeks = (0...(WEEKS_BACK + WEEKS_AHEAD)).map do |i|
      week_start = @first_week + i.weeks
      week_lines = lines.select { |l| l[:date].between?(week_start, week_start + 6.days) }.sort_by { |l| l[:date] }
      {
        week_start: week_start,
        week_end: week_start + 6.days,
        current: week_start == @this_week,
        collected: sum(week_lines, :collected),
        outstanding: sum(week_lines, :outstanding),
        lines: week_lines.map { |l| l.except(:kind) }
      }
    end

    { weeks: weeks, totals: totals(lines) }
  end

  private

  def totals(lines)
    upcoming = lines.select { |l| l[:kind] == :outstanding && l[:date] >= @this_week && l[:date] <= @last_day }
    collected = lines.select { |l| l[:kind] == :collected && l[:date] <= @today }

    {
      expected_upcoming: upcoming.sum { |l| l[:amount] }.round(2),
      collected_recent: collected.sum { |l| l[:amount] }.round(2),
      collected_since: @first_week,
      # Everything unpaid from before this week, not just the weeks shown.
      overdue: overdue_lines.sum { |l| l[:amount] }.round(2)
    }
  end

  def sum(lines, kind)
    lines.select { |l| l[:kind] == kind }.sum { |l| l[:amount] }.round(2)
  end

  def collected_lines
    Payment.completed.where(payment_date: @first_week..@last_day)
           .includes(:enrollment_payment_plan, program_enrollment: %i[child program])
           .filter_map do |payment|
      next unless payment.program_enrollment

      line(:collected, payment.program_enrollment, payment.payment_date, payment.amount, payment_label(payment), 'paid')
    end
  end

  # Every unpaid line from all time; the window and overdue total pick from it.
  def all_outstanding_lines
    @all_outstanding_lines ||= installment_lines + manual_invoice_lines + legacy_class_lines
  end

  def outstanding_lines
    all_outstanding_lines.select { |l| l[:date].between?(@first_week, @last_day) }
  end

  def overdue_lines
    all_outstanding_lines.select { |l| l[:date] < @this_week }
  end

  def installment_lines
    EnrollmentPaymentPlan.includes(program_enrollment: %i[child program]).flat_map do |plan|
      enrollment = plan.program_enrollment
      next [] unless active?(enrollment)

      count = plan.installments.size
      plan.installments.each_with_index.filter_map do |installment, index|
        next if installment['status'] == 'completed' || installment['paid_at'].present?

        due = parse_date(installment['due_date'])
        next unless due

        line(:outstanding, enrollment, due, installment['amount'], "Installment #{index + 1} of #{count}", status_for(due))
      end
    end
  end

  # Pending invoices an admin created by hand. Installment invoices are skipped:
  # the installment above already counts them.
  def manual_invoice_lines
    Payment.pending.where(installment_number: nil)
           .includes(program_enrollment: %i[child program])
           .filter_map do |payment|
      next unless active?(payment.program_enrollment)

      line(:outstanding, payment.program_enrollment, payment.payment_date, payment.amount, payment_label(payment),
           status_for(payment.payment_date))
    end
  end

  # Enrollments from before payment plans, billed per class. Only upcoming
  # classes count: for past ones there's no reliable record of what was paid,
  # and their payments already show as collected.
  def legacy_class_lines
    ProgramEnrollment.where.missing(:enrollment_payment_plan)
                     .where('rate_per_class > 0')
                     .includes(:child, program: :program_classes)
                     .flat_map do |enrollment|
      next [] unless active?(enrollment)

      enrollment.program.program_classes
                .select { |pc| pc.date && pc.date >= @today && pc.date <= @last_day }
                .map { |pc| line(:outstanding, enrollment, pc.date, enrollment.rate_per_class, "Per-class: #{pc.name}", 'due') }
    end
  end

  def active?(enrollment)
    enrollment.present? && enrollment.status != 'cancelled' && enrollment.cancelled_at.nil?
  end

  def status_for(date)
    date < @today ? 'overdue' : 'due'
  end

  def payment_label(payment)
    case payment.payment_type
    when 'enrollment_fee' then 'Enrollment fee'
    when 'tuition'
      count = payment.enrollment_payment_plan&.installments&.size
      if payment.installment_number && count
        "Installment #{payment.installment_number} of #{count}"
      else
        'Tuition'
      end
    else 'Payment'
    end
  end

  def line(kind, enrollment, date, amount, label, status)
    child = enrollment.child
    {
      kind: kind,
      date: date,
      amount: amount.to_d.round(2).to_f,
      label: label,
      status: status,
      enrollment_id: enrollment.id,
      child_name: [child&.first_name, child&.last_name].compact.join(' ').squish,
      program_name: enrollment.program&.name
    }
  end

  def parse_date(value)
    Date.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end
end
