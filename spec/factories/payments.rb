FactoryBot.define do
  factory :payment do
    program_enrollment
    amount { 150.00 }
    payment_date { Date.today }
    payment_method { 'check' }
    status { 'completed' }
    payment_type { 'tuition' }

    trait :enrollment_fee do
      payment_type { 'enrollment_fee' }
      amount { 150.00 }
    end

    trait :stripe do
      payment_method { 'stripe' }
      sequence(:stripe_checkout_session_id) { |n| "cs_test_#{n}" }
      stripe_payment_intent_id { 'pi_test_123' }
      stripe_receipt_url { 'https://pay.stripe.com/receipts/test_123' }
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
