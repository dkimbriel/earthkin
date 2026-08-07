require 'rails_helper'

RSpec.describe Event, type: :model do
  describe 'associations' do
    it { should belong_to(:eventable).optional }
    it { should belong_to(:location).optional }
  end

  describe 'validations' do
    it { should validate_presence_of(:event_type) }
    it { should validate_presence_of(:scheduled_at) }
    it do
      should validate_inclusion_of(:event_type).in_array(
        %w[meet_and_greet orientation field_trip parent_meeting]
      )
    end
  end

  describe 'state transitions' do
    let(:event) { create(:event) }

    describe '#confirm!' do
      it 'updates status to confirmed' do
        event.confirm!
        expect(event.status).to eq('confirmed')
      end
    end

    describe '#complete!' do
      it 'updates status to completed' do
        event.complete!
        expect(event.status).to eq('completed')
        expect(event.completed_at).to be_present
      end
    end

    describe '#cancel!' do
      it 'updates status to cancelled' do
        event.cancel!
        expect(event.status).to eq('cancelled')
        expect(event.cancelled_at).to be_present
      end
    end
  end

  describe 'polymorphic association' do
    it 'can belong to an enrollment application' do
      application = create(:enrollment_application)
      event = create(:event, eventable: application)
      expect(event.eventable).to eq(application)
      expect(event.eventable_type).to eq('EnrollmentApplication')
    end
  end

  describe 'end time / recurrence validations' do
    it 'rejects an ends_at before scheduled_at' do
      event = build(:event, scheduled_at: 2.days.from_now, ends_at: 1.day.from_now)
      expect(event).not_to be_valid
      expect(event.errors[:ends_at]).to be_present
    end

    it 'accepts an ends_at after scheduled_at' do
      expect(build(:event, :multi_day)).to be_valid
    end

    it 'requires recurrence_until when a frequency is set' do
      event = build(:event, recurrence_frequency: 'daily', recurrence_until: nil)
      expect(event).not_to be_valid
      expect(event.errors[:recurrence_until]).to be_present
    end

    it 'requires at least one weekday for weekly recurrence' do
      event = build(:event, recurrence_frequency: 'weekly',
                            recurrence_days_of_week: [], recurrence_until: 4.weeks.from_now.to_date)
      expect(event).not_to be_valid
      expect(event.errors[:recurrence_days_of_week]).to be_present
    end

    it 'rejects an unknown frequency' do
      expect(build(:event, recurrence_frequency: 'yearly')).not_to be_valid
    end
  end

  describe '#occurrences' do
    it 'returns just the scheduled_at for a non-recurring event' do
      event = build(:event, scheduled_at: Time.zone.parse('2026-08-29 09:00'))
      expect(event.occurrences).to eq([event.scheduled_at])
    end

    it 'expands a daily rule up to the until date' do
      start = Time.zone.parse('2026-08-29 09:00')
      event = build(:event, scheduled_at: start, recurrence_frequency: 'daily',
                            recurrence_interval: 1, recurrence_until: '2026-09-01')
      expect(event.occurrences.map(&:to_date).map(&:to_s)).to eq(
        %w[2026-08-29 2026-08-30 2026-08-31 2026-09-01]
      )
    end

    it 'expands a weekly rule onto the selected weekdays' do
      # 2026-08-29 is a Saturday; ask for Mondays (1) and Wednesdays (3).
      start = Time.zone.parse('2026-08-29 18:00')
      event = build(:event, scheduled_at: start, recurrence_frequency: 'weekly',
                            recurrence_days_of_week: [1, 3], recurrence_until: '2026-09-10')
      dates = event.occurrences.map { |o| o.to_date.to_s }
      expect(dates).to eq(%w[2026-08-31 2026-09-02 2026-09-07 2026-09-09])
      # time-of-day is preserved
      expect(event.occurrences.first.hour).to eq(18)
    end

    it 'expands a monthly rule keeping the day-of-month and skipping short months' do
      start = Time.zone.parse('2026-01-31 12:00')
      event = build(:event, scheduled_at: start, recurrence_frequency: 'monthly',
                            recurrence_until: '2026-04-30')
      dates = event.occurrences.map { |o| o.to_date.to_s }
      # February has no 31st, so it is skipped.
      expect(dates).to eq(%w[2026-01-31 2026-03-31])
    end
  end

  describe '#occurrences_json' do
    it 'carries the event duration onto each occurrence' do
      start = Time.zone.parse('2026-08-29 09:00')
      event = build(:event, scheduled_at: start, ends_at: start + 2.hours,
                            recurrence_frequency: 'daily', recurrence_until: '2026-08-30')
      json = event.occurrences_json
      expect(json.size).to eq(2)
      expect(json.first[:end] - json.first[:start]).to eq(2.hours)
    end
  end
end
