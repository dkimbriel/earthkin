FactoryBot.define do
  factory :payment do
    program_enrollment
    amount { 150.00 }
    payment_date { Date.today }
    payment_method { 'venmo' }
    status { 'completed' }
    payment_type { 'tuition' }

    trait :enrollment_fee do
      payment_type { 'enrollment_fee' }
      amount { 150.00 }
    end

    trait :pending do
      status { 'pending' }
    end

    trait :refunded do
      status { 'refunded' }
    end

    trait :with_payment_plan do
      enrollment_payment_plan
      installment_number { 1 }
    end
  end
end
