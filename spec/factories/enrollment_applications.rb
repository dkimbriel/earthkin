FactoryBot.define do
  factory :enrollment_application do
    program
    parent_first_name { Faker::Name.first_name }
    parent_last_name { Faker::Name.last_name }
    parent2_first_name { Faker::Name.first_name }
    parent2_last_name { Faker::Name.last_name }
    parent2_email { Faker::Internet.email }
    parent2_phone { "(#{rand(100..999)}) #{rand(100..999)}-#{rand(1000..9999)}" }
    parent_email { Faker::Internet.email }
    parent_phone { "(#{rand(100..999)}) #{rand(100..999)}-#{rand(1000..9999)}" }
    child_first_name { Faker::Name.first_name }
    child_last_name { Faker::Name.last_name }
    child_date_of_birth { Faker::Date.birthday(min_age: 3, max_age: 6) }
    why_interested { Faker::Lorem.paragraph }
    child_description { Faker::Lorem.paragraph }
    is_local { %w[yes no not_sure].sample }
    referral_source { ['Instagram', 'Facebook', 'Friend or colleague', 'Posted flyer around town', 'Other'].sample }
    status { 'submitted' }
    submitted_at { Time.current }

    trait :reviewed do
      status { 'reviewed' }
      reviewed_at { Time.current }
    end

    trait :meeting_scheduled do
      status { 'meeting_scheduled' }
      reviewed_at { 1.day.ago }
    end

    trait :meeting_completed do
      status { 'meeting_completed' }
      reviewed_at { 2.days.ago }
    end

    trait :fee_requested do
      status { 'fee_requested' }
      reviewed_at { 3.days.ago }
    end

    trait :fee_paid do
      status { 'fee_paid' }
      reviewed_at { 4.days.ago }
      family
      child
    end

    trait :enrolled do
      status { 'enrolled' }
      reviewed_at { 5.days.ago }
      family
      child
    end

    trait :declined do
      status { 'declined' }
      declined_at { Time.current }
    end
  end
end
