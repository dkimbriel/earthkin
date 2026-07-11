class Child < ApplicationRecord
  belongs_to :family
  has_many :program_enrollments, dependent: :destroy
  has_many :programs, through: :program_enrollments
  has_many :enrollment_applications, dependent: :nullify
  has_many :enrollment_form_signatures, dependent: :destroy

  validates :first_name, presence: true
  validates :last_name, presence: true

  def full_name
    "#{first_name} #{last_name}"
  end
end
