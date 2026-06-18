FactoryBot.define do
  factory :enrollment_payment_plan do
    program_enrollment
    payment_plan
    total_amount { 2800.00 }
    enrollment_fee { 150.00 }
    enrollment_fee_paid { false }
    installments do
      [
        { due_date: '2026-08-01', amount: 2800, status: 'pending', paid_at: nil }
      ]
    end

    trait :fee_paid do
      enrollment_fee_paid { true }
      enrollment_fee_paid_at { Time.current }
    end

    trait :with_monthly_plan do
      association :payment_plan, factory: [:payment_plan, :monthly]
      installments do
        10.times.map do |i|
          {
            due_date: Date.new(2026, ((8 + i - 1) % 12) + 1, 1).to_s,
            amount: 280,
            status: 'pending',
            paid_at: nil
          }
        end
      end
    end
  end
end
