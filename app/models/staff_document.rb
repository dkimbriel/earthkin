# A document issued to one employee for signature: a written warning, a
# performance notice, a termination letter. Two parties sign it. The employee
# acknowledges receipt (agreement is not implied, and they may attach written
# comments), and the director counter-signs. Either may go first; the document
# is complete only once both have signed.
#
# Unlike enrollment forms, which read their text live from the template until
# the moment of signing, a staff document copies the resolved body at issue
# time. A notice is specific to one person and one set of facts, and editing
# the template later must never rewrite a letter already issued.
class StaffDocument < ApplicationRecord
  include SoftDeletable
  include SignatureAuditable

  # An HR record has to outlive the employee record it concerns. Staff are
  # routinely archived once they leave, and a signed termination letter must
  # still open, list, and print after that.
  belongs_to :teacher, -> { with_deleted }
  belongs_to :form_template, optional: true
  belongs_to :issued_by, class_name: 'User', optional: true

  STATUSES = %w[pending partially_signed signed].freeze

  validates :title, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :pending, -> { where(status: %w[pending partially_signed]) }
  scope :complete, -> { where(status: 'signed') }

  # Issue a document to an employee, resolving {{tokens}} once and storing the
  # result. Pass a template to start from its skeleton, or a body outright.
  def self.issue!(teacher:, issued_by:, title:, body: nil, form_template: nil, employee_position: nil)
    document = new(
      teacher: teacher,
      issued_by: issued_by,
      form_template: form_template,
      title: title.presence || form_template&.name,
      employee_position: employee_position
    )
    document.body = document.send(:interpolate_tokens, body.presence || form_template&.body.to_s)
    document.save!
    document
  end

  # The exact text being signed: frozen at the first signature so both parties
  # are demonstrably signing the same document.
  def signing_text
    body_snapshot.presence || body.to_s
  end

  def employee_signed?
    employee_signed_at.present?
  end

  def director_signed?
    director_signed_at.present?
  end

  def complete?
    employee_signed? && director_signed?
  end

  # The employee acknowledges the notice. Comments are optional and never
  # block signing: an acknowledgment is a record of receipt, not of agreement.
  def sign_as_employee!(name:, email: nil, ip: nil, user_agent: nil, comments: nil, form_fields: nil)
    raise ArgumentError, 'Signature name is required' if name.blank?
    raise ArgumentError, 'You have already signed this document' if employee_signed?

    fields = (form_fields.presence || self.form_fields || {})
    missing = FormFieldRequirements.errors_for(signing_text, fields)
    raise ArgumentError, "Please complete the required fields: #{missing.join('; ')}" if missing.any?

    freeze_text!
    update!(
      employee_signed_by_name: name,
      employee_signed_by_email: email,
      employee_signature_ip: ip,
      employee_signed_at: Time.current,
      employee_comments: comments.presence,
      form_fields: fields,
      status: next_status(employee: true)
    )

    log_signature('employee_signed', name, email, ip, user_agent)
  end

  # The director counter-signs, confirming the notice was delivered.
  def countersign!(name:, email: nil, ip: nil, user_agent: nil)
    raise ArgumentError, 'Signature name is required' if name.blank?
    raise ArgumentError, 'This document has already been counter-signed' if director_signed?

    freeze_text!
    update!(
      director_signed_by_name: name,
      director_signed_by_email: email,
      director_signature_ip: ip,
      director_signed_at: Time.current,
      status: next_status(director: true)
    )

    log_signature('director_signed', name, email, ip, user_agent)
  end

  def as_json(_options = {})
    {
      id: id,
      teacher_id: teacher_id,
      teacher_name: teacher.full_name,
      title: title,
      employee_position: employee_position,
      status: status,
      body: signing_text,
      employee_signed_by_name: employee_signed_by_name,
      employee_signed_at: employee_signed_at,
      employee_comments: employee_comments,
      director_signed_by_name: director_signed_by_name,
      director_signed_at: director_signed_at,
      form_fields: form_fields,
      issued_by_name: issued_by&.display_name,
      audit_log: audit_log,
      created_at: created_at
    }
  end

  private

  # Copy the live body into the snapshot the first time anyone signs, so a
  # later edit cannot change what was already signed.
  def freeze_text!
    update_columns(body_snapshot: body.to_s, updated_at: Time.current) if body_snapshot.blank?
  end

  def next_status(employee: false, director: false)
    both = (employee || employee_signed?) && (director || director_signed?)
    both ? 'signed' : 'partially_signed'
  end

  def log_signature(event, name, email, ip, user_agent)
    log_event!(event,
               'by' => name,
               'email' => email,
               'ip' => ip,
               'user_agent' => user_agent,
               'document_sha256' => document_fingerprint(signing_text))
  end

  def interpolate_tokens(text)
    vars = StaffDocumentTokenVars.for(self)
    text.to_s.gsub(/{{\s*(\w+)\s*}}/) do
      key = Regexp.last_match(1)
      (vars[key.to_sym] || vars[key]).to_s
    end
  end
end
