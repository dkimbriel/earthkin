FactoryBot.define do
  factory :email do
    association :emailable, factory: :enrollment_application
    mailer_class { 'EnrollmentMailer' }
    email_type { 'inquiry_response' }
    recipient { 'parent@example.com' }
    subject { 'Welcome to Nature Preschool' }
    status { 'queued' }
    metadata { {} }

    trait :sent do
      status { 'sent' }
      sent_at { Time.current }
    end

    trait :failed do
      status { 'failed' }
      failed_at { Time.current }
      error_message { 'SMTP Error' }
    end

    trait :for_payment do
      association :emailable, factory: :payment
      mailer_class { 'PaymentMailer' }
      email_type { 'invoice' }
    end

    trait :for_parent do
      association :emailable, factory: :parent
      mailer_class { 'ParentMailer' }
      email_type { 'welcome_email' }
    end
  end
end
