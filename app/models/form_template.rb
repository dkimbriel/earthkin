class FormTemplate < ApplicationRecord
  # The four enrollment forms every family signs.
  DEFAULT_FORMS = {
    'family_agreement' => 'Family Agreement & Waiver',
    'parent_guardian_contact' => 'Parent/Guardian Contact Form',
    'medication_administration' => 'Medication Administration Form',
    'health_medical_care' => 'Health & Medical Care Form'
  }.freeze

  # Read-only {{tokens}} that get filled in with the family's real details when
  # a parent opens the form. Distinct from the interactive [[field]] markers the
  # parent fills in. Values are built by FormTokenVars.
  KNOWN_TOKENS = %w[child_name parent_name parent2_name program_name school_name school_year current_date].freeze

  # Human-readable description of each token, shown in the form editor and the
  # Help Center.
  TOKEN_INFO = {
    'child_name' => "The child's full name, from the enrollment application.",
    'parent_name' => "The parent/guardian's full name, from the application.",
    'parent2_name' => "The second parent/guardian's full name if one is on the application (blank otherwise).",
    'program_name' => "The program the child is enrolling in.",
    'school_name' => 'The school name.',
    'school_year' => "The program's school year (e.g. 2026–2027).",
    'current_date' => "Today's date, filled in when the parent opens the form."
  }.freeze

  CATEGORIES = %w[enrollment staff].freeze

  # Staff documents (written warnings, termination letters) are issued to an
  # employee rather than a family, so they get their own token vocabulary.
  # Anything case-specific (dates, incidents, final pay) is typed into the
  # letter body when it is issued, not tokenized.
  STAFF_FORMS = {
    'termination_letter' => 'Termination Letter'
  }.freeze

  STAFF_TOKENS = %w[employee_name employee_position employee_email school_name current_date issued_by issued_by_title].freeze

  STAFF_TOKEN_INFO = {
    'employee_name' => "The employee's full name, from their teacher record.",
    'employee_position' => "The employee's position or title, from their teacher record.",
    'employee_email' => "The employee's email address on file.",
    'school_name' => 'The school name.',
    'current_date' => "Today's date, filled in when the document is issued.",
    'issued_by' => 'The name of the admin who issued the document.',
    'issued_by_title' => "The issuer's title (defaults to Executive Director)."
  }.freeze

  has_many :enrollment_form_signatures, dependent: :restrict_with_error
  has_many :staff_documents, dependent: :nullify

  validates :key, presence: true, uniqueness: true
  validates :name, presence: true
  validates :category, inclusion: { in: CATEGORIES }
  validate :tokens_must_be_valid

  scope :enrollment, -> { where(category: 'enrollment') }
  scope :staff, -> { where(category: 'staff') }

  # The tokens a template may use, which depend on who signs it.
  def self.tokens_for(category)
    category.to_s == 'staff' ? STAFF_TOKENS : KNOWN_TOKENS
  end

  def self.token_info_for(category)
    category.to_s == 'staff' ? STAFF_TOKEN_INFO : TOKEN_INFO
  end

  def known_tokens
    self.class.tokens_for(category)
  end

  # Idempotently create the four standard forms (called when forms are sent).
  def self.ensure_defaults!
    DEFAULT_FORMS.map do |key, name|
      find_or_create_by!(key: key) do |form|
        form.name = name
        form.category = 'enrollment'
        form.body = "#{name}\n\n(Form text not set yet, an admin can edit this under Emails → Enrollment Forms.)"
      end
    end
  end

  # Staff document skeletons, created on demand when an admin issues one.
  def self.ensure_staff_defaults!
    STAFF_FORMS.map do |key, name|
      find_or_create_by!(key: key) do |form|
        form.name = name
        form.category = 'staff'
        form.body = StaffDocumentTemplates.body_for(key)
      end
    end
  end

  private

  # Reject {{tokens}} that aren't in KNOWN_TOKENS so a typo can't slip through
  # and show up verbatim on a form a family signs. Interactive [[field]] markers
  # are left untouched.
  def tokens_must_be_valid
    used = body.to_s.scan(/{{\s*(\w+)\s*}}/).flatten.uniq
    unknown = used - known_tokens
    return if unknown.empty?

    errors.add(:base, "Unknown token(s): #{unknown.map { |t| "{{#{t}}}" }.join(', ')}")
  end
end
