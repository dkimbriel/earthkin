FactoryBot.define do
  factory :program_class do
    program
    name { "#{Faker::Adjective.positive.titleize} Explorers" }
    date { Date.today }
  end
end
