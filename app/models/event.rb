class Event < ApplicationRecord
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

  scope :upcoming, -> { where(status: ['scheduled', 'confirmed']).where('scheduled_at > ?', Time.current) }
  scope :past, -> { where('scheduled_at < ?', Time.current) }
  scope :by_type, ->(type) { where(event_type: type) }
  scope :pending_selection, -> { where(status: 'pending_selection') }
  scope :published, -> { where(published: true) }

  before_validation :generate_confirmation_token, on: :create, if: :pending_selection?

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

  private

  def generate_confirmation_token
    self.confirmation_token ||= SecureRandom.urlsafe_base64(24)
  end

  def proposed_dates_include?(time)
    proposed_dates_as_times.any? { |d| d.to_i == time.to_i }
  end
end
