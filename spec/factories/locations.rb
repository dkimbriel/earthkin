FactoryBot.define do
  factory :location do
    name { Faker::Lorem.words(number: 2).join(' ').titleize }
    address { Faker::Address.street_address }
  end
end
