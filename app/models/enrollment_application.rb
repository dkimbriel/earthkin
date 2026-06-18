class EnrollmentApplication < ApplicationRecord
  belongs_to :family, optional: true
  belongs_to :program
  belongs_to :child, optional: true
  belongs_to :selected_payment_plan, class_name: 'PaymentPlan', optional: true
  has_one :program_enrollment, dependent: :nullify
  has_many :events, as: :eventable, dependent: :destroy
  has_many :emails, as: :emailable, dependent: :destroy

  validates :parent_first_name, :parent_last_name, :parent_email, presence: true
  validates :child_first_name, :child_last_name, presence: true, unless: :invited?
  validates :child_date_of_birth, :child_description, :why_interested, presence: true, unless: :invited?
  # Parent 2 fields are optional (no presence validation)
  validates :is_local, :referral_source, presence: true, unless: :invited?
  validates :parent_phone, presence: true, unless: :invited?
  validates :parent_phone, :parent2_phone, format: {
    with: /\A\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}\z/,
    message: 'must be a valid 10-digit phone number'
  }, allow_blank: true
  validates :status, inclusion: {
    in: %w[invited submitted reviewed meeting_scheduled meeting_completed
           fee_requested fee_paid signing_docs enrolled declined]
  }

  before_save :normalize_phone_numbers
  before_create :generate_payment_selection_token

  scope :pending_review, -> { where(status: 'submitted') }
  scope :awaiting_meeting, -> { where(status: 'reviewed') }
  scope :active, -> { where.not(status: ['enrolled', 'declined']) }
  scope :invited, -> { where(status: 'invited') }

  def invited?
    status == 'invited'
  end

  # State machine transitions
  def mark_reviewed!
    update!(status: 'reviewed', reviewed_at: Time.current)
  end

  def schedule_meeting!
    update!(status: 'meeting_scheduled')
  end

  def complete_meeting!
    update!(status: 'meeting_completed')
  end

  def request_enrollment_fee!
    # Ensure payment selection token exists before requesting fee
    if payment_selection_token.blank?
      self.payment_selection_token = SecureRandom.urlsafe_base64(24)
      self.payment_selection_token_created_at = Time.current
    end
    update!(status: 'fee_requested')
  end

  def mark_fee_paid!
    update!(status: 'fee_paid')
  end

  def send_enrollment_forms!
    update!(status: 'signing_docs')
  end

  def enroll!
    update!(status: 'enrolled')
  end

  def decline!(notes = nil)
    update!(
      status: 'declined',
      declined_at: Time.current,
      admin_notes: [admin_notes, notes].compact.join("\n")
    )
  end

  def full_child_name
    "#{child_first_name} #{child_last_name}"
  end

  def full_parent_name
    "#{parent_first_name} #{parent_last_name}"
  end

  def meet_and_greet
    events.find_by(event_type: 'meet_and_greet')
  end

  def email_sent?(email_type)
    emails.sent.exists?(email_type: email_type)
  end

  def latest_email_for(email_type)
    emails.by_type(email_type).recent.first
  end

  def payment_selection_url
    url_options = Rails.application.config.action_mailer.default_url_options || { host: 'localhost', port: 3000 }
    Rails.application.routes.url_helpers.payment_selection_url(
      payment_selection_token,
      **url_options
    )
  end

  # Returns the enrollment fee to use (custom override or program default)
  def effective_enrollment_fee
    custom_enrollment_fee || program&.enrollment_fee || 150.0
  end

  # Returns the tuition amount to use (custom override or payment plan default)
  def effective_tuition_amount
    custom_tuition_amount || selected_payment_plan&.total_amount || program&.payment_plans&.active&.first&.total_amount
  end

  # Calculate effective installment amount for a given payment plan
  def effective_installment_amount(payment_plan)
    tuition = effective_tuition_amount || payment_plan.total_amount
    tuition / payment_plan.installment_count
  end

  # Returns payment plan options with effective amounts calculated for this application
  # Useful for views that need to display payment plans with custom pricing
  def payment_plan_options
    program.payment_plans.active.map do |plan|
      tuition = effective_tuition_amount || plan.total_amount
      {
        id: plan.id,
        name: plan.name,
        description: plan.description,
        installment_count: plan.installment_count,
        total_amount: tuition,
        installment_amount: tuition / plan.installment_count,
        default_total_amount: plan.total_amount,
        default_installment_amount: plan.installment_amount
      }
    end
  end

  private

  def generate_payment_selection_token
    self.payment_selection_token ||= SecureRandom.urlsafe_base64(24)
    self.payment_selection_token_created_at ||= Time.current
  end

  def normalize_phone_numbers
    [[:parent_phone, :parent_phone=], [:parent2_phone, :parent2_phone=]].each do |getter, setter|
      phone = send(getter)
      next if phone.blank?

      # Strip all non-numeric characters
      digits = phone.gsub(/\D/, '')

      # Format as (XXX) XXX-XXXX if we have 10 digits
      if digits.length == 10
        send(setter, "(#{digits[0..2]}) #{digits[3..5]}-#{digits[6..9]}")
      end
    end
  end
end
