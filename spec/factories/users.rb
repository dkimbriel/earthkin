FactoryBot.define do
  factory :user do
    email { Faker::Internet.email }
    password { 'password123' }
    password_confirmation { 'password123' }
    role { 'admin' }

    trait :teacher do
      role { 'teacher' }
    end

    trait :parent do
      role { 'parent' }
    end
  end
end
