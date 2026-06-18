class ProgramClass < ApplicationRecord
  belongs_to :program
  belongs_to :location, optional: true
  has_many :program_class_teachers, dependent: :destroy
  has_many :teachers, through: :program_class_teachers

  validates :name, presence: true, uniqueness: { scope: :program_id }
  validates :date, presence: true
end
