class EnrollmentFormSignature < ApplicationRecord
  belongs_to :child
  belongs_to :form_template
  belongs_to :enrollment_application, optional: true

  STATUSES = %w[pending signed].freeze

  validates :status, inclusion: { in: STATUSES }
  validates :signed_by_name, presence: true, if: :signed?

  scope :pending, -> { where(status: 'pending') }
  scope :signed, -> { where(status: 'signed') }

  after_create :log_issued

  def signed?
    status == 'signed'
  end

  def sign!(name:, email: nil, ip: nil, user_agent: nil, response_text: nil, form_fields: nil)
    raise ArgumentError, 'Signature name is required' if name.blank?
    raise ArgumentError, 'Form is already signed' if signed?

    update!(
      status: 'signed',
      signed_by_name: name,
      signed_by_email: email,
      signature_ip: ip,
      signed_at: Time.current,
      response_text: response_text.presence,
      form_fields: form_fields.presence || {},
      form_body_snapshot: form_template.body
    )

    log_event!('signed',
               'by' => name,
               'email' => email,
               'ip' => ip,
               'user_agent' => user_agent,
               'document_sha256' => Digest::SHA256.hexdigest(form_template.body.to_s))
  end

  def record_view!(email: nil, ip: nil, user_agent: nil)
    log_event!('viewed', 'by' => email, 'ip' => ip, 'user_agent' => user_agent)
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
      signed_by_email: signed_by_email,
      signed_at: signed_at,
      response_text: response_text,
      form_fields: form_fields,
      audit_log: audit_log,
      created_at: created_at
    }
  end

  private

  # Append an event to the audit trail without touching validations —
  # audit entries must never be blocked or rewritten by model state.
  def log_event!(event, details = {})
    entry = { 'event' => event, 'at' => Time.current.iso8601 }.merge(details.compact)
    update_columns(audit_log: audit_log + [entry], updated_at: Time.current)
  end

  def log_issued
    log_event!('issued')
  end
end
