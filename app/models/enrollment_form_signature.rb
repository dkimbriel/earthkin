class EnrollmentFormSignature < ApplicationRecord
  belongs_to :child
  belongs_to :form_template
  belongs_to :enrollment_application, optional: true

  STATUSES = %w[pending signed].freeze

  validates :status, inclusion: { in: STATUSES }
  validates :signed_by_name, presence: true, if: :signed?

  scope :pending, -> { where(status: 'pending') }
  scope :signed, -> { where(status: 'signed') }

  def signed?
    status == 'signed'
  end

  def sign!(name:, email: nil, ip: nil)
    raise ArgumentError, 'Signature name is required' if name.blank?
    raise ArgumentError, 'Form is already signed' if signed?

    update!(
      status: 'signed',
      signed_by_name: name,
      signed_by_email: email,
      signature_ip: ip,
      signed_at: Time.current,
      form_body_snapshot: form_template.body
    )
  end

  def as_json(_options = {})
    {
      id: id,
      child_id: child_id,
      child_name: child.full_name,
      form_key: form_template.key,
      form_name: form_template.name,
      status: status,
      signed_by_name: signed_by_name,
      signed_at: signed_at,
      created_at: created_at
    }
  end
end
