class AddEndTimeAndRecurrenceToEvents < ActiveRecord::Migration[7.0]
	def change
		# Optional end time lets a single event span a range (e.g. a vacation
		# Aug 29 - Sept 5) instead of a single point in time.
		add_column :events, :ends_at, :datetime

		# Recurrence rule for repeating events (e.g. a weekly class). The series is
		# stored as a rule and expanded into occurrences at render time; there are
		# no per-occurrence rows. recurrence_days_of_week holds weekdays for weekly
		# recurrence (0 = Sunday ... 6 = Saturday), mirroring the jsonb-array
		# precedent set by proposed_dates.
		add_column :events, :recurrence_frequency, :string
		add_column :events, :recurrence_interval, :integer, default: 1, null: false
		add_column :events, :recurrence_days_of_week, :jsonb, default: [], null: false
		add_column :events, :recurrence_until, :date
	end
end
