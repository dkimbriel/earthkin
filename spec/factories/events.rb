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
  end
end
