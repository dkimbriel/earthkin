FactoryBot.define do
  factory :program do
    name { Faker::Educator.course_name }
    description { Faker::Lorem.paragraph }
    start_date { Date.current + 3.months }
    end_date { Date.current + 12.months }
    capacity { 12 }
  end
end
