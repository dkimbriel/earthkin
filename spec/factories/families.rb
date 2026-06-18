FactoryBot.define do
  factory :family do
    name { Faker::Name.last_name }
  end
end
