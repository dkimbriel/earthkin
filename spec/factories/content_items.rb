FactoryBot.define do
  factory :content_item do
    title { Faker::Book.title }
    url { 'https://drive.google.com/file/d/abc123' }
    category { 'general' }
    visibility { 'all_staff' }

    trait :specific do
      visibility { 'specific_teachers' }
    end
  end
end
