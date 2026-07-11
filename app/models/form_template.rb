class FormTemplate < ApplicationRecord
  # The four enrollment forms every family signs.
  DEFAULT_FORMS = {
    'family_agreement' => 'Family Agreement & Waiver',
    'parent_guardian_contact' => 'Parent/Guardian Contact Form',
    'medication_administration' => 'Medication Administration Form',
    'health_medical_care' => 'Health & Medical Care Form'
  }.freeze

  has_many :enrollment_form_signatures, dependent: :restrict_with_error

  validates :key, presence: true, uniqueness: true
  validates :name, presence: true

  # Idempotently create the four standard forms (called when forms are sent).
  def self.ensure_defaults!
    DEFAULT_FORMS.map do |key, name|
      find_or_create_by!(key: key) do |form|
        form.name = name
        form.body = "#{name}\n\n(Form text not set yet — an admin can edit this under Emails → Enrollment Forms.)"
      end
    end
  end
end
