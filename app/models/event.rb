class Event < ApplicationRecord
  RECURRENCE_FREQUENCIES = %w[daily weekly monthly].freeze
  # Defensive cap so a bad rule can never expand into an unbounded list.
  MAX_OCCURRENCES = 500

  belongs_to :eventable, polymorphic: true, optional: true
  belongs_to :location, optional: true

  validates :event_type, presence: true, inclusion: {
    in: %w[meet_and_greet orientation field_trip parent_meeting open_house other]
  }
  validates :scheduled_at, presence: true, unless: :pending_selection?
  validates :status, inclusion: {
    in: %w[pending_selection scheduled confirmed completed cancelled rescheduled]
  }
  validates :proposed_dates, presence: true, if: :pending_selection?
  validates :confirmation_token, presence: true, uniqueness: true, if: :pending_selection?
  validates :recurrence_frequency, inclusion: { in: RECURRENCE_FREQUENCIES }, allow_nil: true
  validate :ends_at_after_scheduled_at
  validate :recurrence_rule_is_complete

  scope :upcoming, -> { where(status: ['scheduled', 'confirmed']).where('scheduled_at > ?', Time.current) }
  scope :past, -> { where('scheduled_at < ?', Time.current) }
  scope :by_type, ->(type) { where(event_type: type) }
  scope :pending_selection, -> { where(status: 'pending_selection') }
  scope :published, -> { where(published: true) }

  before_validation :generate_confirmation_token, on: :create, if: :pending_selection?
  before_validation :normalize_recurrence_days

  def pending_selection?
    status == 'pending_selection'
  end

  def confirm!
    update!(status: 'confirmed')
  end

  def complete!(outcome_notes = nil)
    update!(
      status: 'completed',
      completed_at: Time.current,
      outcome_notes: outcome_notes
    )
  end

  def cancel!(reason = nil)
    update!(
      status: 'cancelled',
      cancelled_at: Time.current,
      notes: [notes, reason].compact.join("\n")
    )
  end

  def reschedule!(new_time)
    update!(
      status: 'rescheduled',
      scheduled_at: new_time
    )
  end

  def confirm_date_selection!(selected_date)
    selected_time = selected_date.is_a?(Time) ? selected_date : Time.zone.parse(selected_date.to_s)

    # Verify the selected date is one of the proposed dates
    unless proposed_dates_include?(selected_time)
      raise ArgumentError, "Selected date is not one of the proposed dates"
    end

    update!(
      status: 'scheduled',
      scheduled_at: selected_time
    )
  end

  def proposed_dates_as_times
    proposed_dates.map { |d| Time.zone.parse(d.to_s) }
  end

  def recurring?
    recurrence_frequency.present?
  end

  # Duration of a single occurrence, or nil for a point-in-time event.
  def occurrence_duration
    return nil unless ends_at && scheduled_at

    ends_at - scheduled_at
  end

  # Concrete start times for this event. A non-recurring event yields a single
  # start; a recurring event is expanded (bounded by recurrence_until) into one
  # start per occurrence. Each occurrence keeps scheduled_at's time-of-day.
  def occurrences
    return [] unless scheduled_at
    return [scheduled_at] unless recurring? && recurrence_until

    step = [recurrence_interval.to_i, 1].max
    limit = recurrence_until.end_of_day
    results = []

    case recurrence_frequency
    when 'daily'
      current = scheduled_at
      while current <= limit && results.size < MAX_OCCURRENCES
        results << current
        current += step.days
      end
    when 'weekly'
      days = Array(recurrence_days_of_week).map(&:to_i).uniq
      days = [scheduled_at.wday] if days.empty?
      week_start = scheduled_at.beginning_of_week(:sunday)
      until week_start > limit || results.size >= MAX_OCCURRENCES
        days.sort.each do |wday|
          occ = (week_start + wday.days)
                .change(hour: scheduled_at.hour, min: scheduled_at.min, sec: scheduled_at.sec)
          next if occ < scheduled_at || occ > limit

          results << occ
        end
        week_start += step.weeks
      end
    when 'monthly'
      target_day = scheduled_at.day
      month_anchor = scheduled_at.beginning_of_month
      until month_anchor > limit || results.size >= MAX_OCCURRENCES
        # Skip months that don't have the target day (e.g. day 31 in February).
        if month_anchor.end_of_month.day >= target_day
          occ = month_anchor.change(
            day: target_day,
            hour: scheduled_at.hour, min: scheduled_at.min, sec: scheduled_at.sec
          )
          results << occ if occ >= scheduled_at && occ <= limit
        end
        month_anchor = month_anchor.advance(months: step)
      end
    end

    results.sort
  end

  # Occurrence start/end pairs for the calendar API.
  def occurrences_json
    duration = occurrence_duration
    occurrences.map do |start|
      { start: start, end: duration ? start + duration : nil }
    end
  end

  private

  # Form params arrive as strings; store weekdays as sorted unique integers.
  def normalize_recurrence_days
    return if recurrence_days_of_week.blank?

    self.recurrence_days_of_week = Array(recurrence_days_of_week).map(&:to_i).uniq.sort
  end

  def ends_at_after_scheduled_at
    return if ends_at.blank? || scheduled_at.blank?
    return if ends_at > scheduled_at

    errors.add(:ends_at, 'must be after the start time')
  end

  def recurrence_rule_is_complete
    return if recurrence_frequency.blank?

    if recurrence_until.blank?
      errors.add(:recurrence_until, 'is required for a repeating event')
    elsif scheduled_at.present? && recurrence_until < scheduled_at.to_date
      errors.add(:recurrence_until, 'must be on or after the start date')
    end

    if recurrence_frequency == 'weekly' && Array(recurrence_days_of_week).empty?
      errors.add(:recurrence_days_of_week, 'must include at least one day for weekly recurrence')
    end
  end

  def generate_confirmation_token
    self.confirmation_token ||= SecureRandom.urlsafe_base64(24)
  end

  def proposed_dates_include?(time)
    proposed_dates_as_times.any? { |d| d.to_i == time.to_i }
  end
end
