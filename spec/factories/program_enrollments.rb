FactoryBot.define do
  factory :program_enrollment do
    program
    child
    status { 'confirmed' }
    rate_per_class { 35.00 }

    trait :pending do
      status { 'pending' }
    end

    trait :cancelled do
      status { 'cancelled' }
      cancelled_at { Time.current }
    end

    trait :with_application do
      enrollment_application
    end
  end
end
