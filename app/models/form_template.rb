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

  has_many :enrollment_form_signatures, dependent: :restrict_with_error

  validates :key, presence: true, uniqueness: true
  validates :name, presence: true
  validate :tokens_must_be_valid

  # Idempotently create the four standard forms (called when forms are sent).
  def self.ensure_defaults!
    DEFAULT_FORMS.map do |key, name|
      find_or_create_by!(key: key) do |form|
        form.name = name
        form.body = "#{name}\n\n(Form text not set yet — an admin can edit this under Emails → Enrollment Forms.)"
      end
    end
  end

  private

  # Reject {{tokens}} that aren't in KNOWN_TOKENS so a typo can't slip through
  # and show up verbatim on a form a family signs. Interactive [[field]] markers
  # are left untouched.
  def tokens_must_be_valid
    used = body.to_s.scan(/{{\s*(\w+)\s*}}/).flatten.uniq
    unknown = used - KNOWN_TOKENS
    return if unknown.empty?

    errors.add(:base, "Unknown token(s): #{unknown.map { |t| "{{#{t}}}" }.join(', ')}")
  end
end
