FactoryBot.define do
  factory :event do
    association :eventable, factory: :enrollment_application
    event_type { 'meet_and_greet' }
    scheduled_at { 1.week.from_now }
    status { 'scheduled' }

    trait :confirmed do
      status { 'confirmed' }
    end

    trait :completed do
      status { 'completed' }
      completed_at { 1.day.ago }
    end

    trait :cancelled do
      status { 'cancelled' }
      cancelled_at { Time.current }
    end

    trait :pending_selection do
      status { 'pending_selection' }
      scheduled_at { nil }
      proposed_dates { [1.week.from_now, 2.weeks.from_now, 3.weeks.from_now] }
      confirmation_token { SecureRandom.urlsafe_base64(24) }
    end

    trait :multi_day do
      scheduled_at { 1.week.from_now }
      ends_at { 8.days.from_now }
    end

    trait :recurring do
      scheduled_at { 1.week.from_now }
      recurrence_frequency { 'weekly' }
      recurrence_interval { 1 }
      recurrence_days_of_week { [(1.week.from_now).wday] }
      recurrence_until { 5.weeks.from_now.to_date }
    end
  end
end
