FactoryBot.define do
  factory :program_class do
    program
    sequence(:name) { |n| "#{Faker::Adjective.positive.titleize} Explorers #{n}" }
    date { Date.today }
  end
end
