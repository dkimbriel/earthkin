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

  # The form as presented to the family: the template body with dynamic
  # markers expanded. [[payment-plans]] becomes one checkbox per active
  # payment plan of the child's program, straight from the database.
  def rendered_body
    form_template.body.to_s
                 .gsub('[[payment-plans]]') { payment_plan_options_markup }
                 .gsub('[[tuition-plan]]') { tuition_plan_markup }
  end

  # Field values to pre-check when the parent opens the form — currently the
  # payment plan their enrollment already uses.
  def suggested_fields
    plan_id = enrollment&.enrollment_payment_plan&.payment_plan_id
    plan_id ? { "plan_#{plan_id}" => true } : {}
  end

  def sign!(name:, email: nil, ip: nil, user_agent: nil, response_text: nil, form_fields: nil)
    raise ArgumentError, 'Signature name is required' if name.blank?
    raise ArgumentError, 'Form is already signed' if signed?

    document = rendered_body
    missing = FormFieldRequirements.errors_for(document, form_fields)
    raise ArgumentError, "Please complete the required fields: #{missing.join('; ')}" if missing.any?

    update!(
      status: 'signed',
      signed_by_name: name,
      signed_by_email: email,
      signature_ip: ip,
      signed_at: Time.current,
      response_text: response_text.presence,
      form_fields: form_fields.presence || {},
      form_body_snapshot: document
    )

    log_event!('signed',
               'by' => name,
               'email' => email,
               'ip' => ip,
               'user_agent' => user_agent,
               'document_sha256' => Digest::SHA256.hexdigest(document))
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

  def enrollment
    enrollment_application&.program_enrollment || child.program_enrollments.order(:created_at).last
  end

  def payment_plan_options_markup
    program = enrollment&.program
    plans = program ? PaymentPlan.where(program: program, active: true).order(:display_order) : PaymentPlan.none
    return '(Payment plan options are arranged directly with the school.)' if plans.blank?

    lines = plans.map.with_index(1) do |plan, index|
      amount = ActiveSupport::NumberHelper.number_to_delimited(plan.installment_amount.to_i)
      label = "Option #{index}: #{plan.name} — #{plan.installment_count} payment(s) of $#{amount}"
      label += " (#{plan.description})" if plan.description.present?
      "[[checkbox:plan_#{plan.id}|#{sanitize_label(label)}]]"
    end

    keys = plans.map { |plan| "plan_#{plan.id}" }.join(',')
    (lines + ["[[require-one:#{keys}|Please choose one payment plan option]]"]).join("\n")
  end

  # A statement of THIS child's tuition and selected plan, with due dates on
  # the program's billing day — used by [[tuition-plan]] so each family's
  # agreement shows only their own rate.
  def tuition_plan_markup
    enr = enrollment
    epp = enr&.enrollment_payment_plan

    if epp&.payment_plan
      plan = epp.payment_plan
      total = epp.total_amount
      count = plan.installment_count.to_i
      per = count.positive? ? (total / count) : total
      installments = Array(epp.installments)
      first_due = begin
        installments.first && Date.parse(installments.first['due_date'].to_s)
      rescue Date::Error
        nil
      end

      lines = ["**Tuition for #{child.full_name} is $#{money(total)}** (#{plan.name})."]
      lines << if count <= 1
        due = first_due ? " Payment is due #{first_due.strftime('%B %-d, %Y')}." : ''
        "Selected plan: pay in full ($#{money(total)}).#{due}"
      elsif first_due
        "Selected plan: #{count} payments of $#{money(per)}, due on the #{first_due.day.ordinalize} of each month beginning #{first_due.strftime('%B %-d, %Y')}."
      else
        "Selected plan: #{count} payments of $#{money(per)}."
      end
      lines.join("\n\n")
    else
      'Your tuition and payment plan will be confirmed with the school before your first payment is due.'
    end
  end

  def money(value)
    ActiveSupport::NumberHelper.number_to_delimited(format('%.2f', value.to_f))
  end

  # Labels live inside [[...|label]] markers, so strip the delimiters.
  def sanitize_label(text)
    text.tr('|', '/').gsub(']]', ')')
  end

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
