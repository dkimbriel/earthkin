# The audit trail shared by every signable document, enrollment forms and
# staff documents alike. An electronic signature is only as good as the record
# behind it, so each event (issued, viewed, signed) is appended with who, when,
# from where, and a SHA-256 fingerprint of the exact text presented at signing.
module SignatureAuditable
  extend ActiveSupport::Concern

  included do
    after_create :log_issued
  end

  def record_view!(email: nil, ip: nil, user_agent: nil)
    log_event!('viewed', 'by' => email, 'ip' => ip, 'user_agent' => user_agent)
  end

  # Append an event to the audit trail without touching validations.
  # Audit entries must never be blocked or rewritten by model state.
  def log_event!(event, details = {})
    entry = { 'event' => event, 'at' => Time.current.iso8601 }.merge(details.compact)
    update_columns(audit_log: audit_log + [entry], updated_at: Time.current)
  end

  def document_fingerprint(text)
    Digest::SHA256.hexdigest(text.to_s)
  end

  private

  def log_issued
    log_event!('issued')
  end
end
