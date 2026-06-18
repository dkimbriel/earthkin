FactoryBot.define do
  factory :payment_plan do
    program
    name { 'Full Payment' }
    description { 'Pay in full by August 1' }
    total_amount { 2800.00 }
    installment_count { 1 }
    installment_schedule { [{ month: 8, day: 1, amount: 2800 }] }
    active { true }
    display_order { 1 }

    trait :monthly do
      name { 'Monthly Payments' }
      description { '10 monthly payments starting August 1' }
      installment_count { 10 }
      installment_schedule do
        10.times.map do |i|
          { month: ((8 + i - 1) % 12) + 1, day: 1, amount: 280 }
        end
      end
      display_order { 4 }
    end

    trait :quarterly do
      name { 'Quarterly Payments' }
      description { 'Four quarterly payments' }
      installment_count { 4 }
      installment_schedule { [
        { month: 8, day: 1, amount: 700 },
        { month: 10, day: 1, amount: 700 },
        { month: 1, day: 1, amount: 700 },
        { month: 4, day: 1, amount: 700 }
      ]}
      display_order { 3 }
    end

    trait :inactive do
      active { false }
    end
  end
end
