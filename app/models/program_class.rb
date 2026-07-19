class ProgramClass < ApplicationRecord
  include SoftDeletable

  belongs_to :program
  belongs_to :location, optional: true
  has_many :program_class_teachers, dependent: :destroy
  has_many :teachers, through: :program_class_teachers

  cascades_soft_delete :program_class_teachers

  validates :name, presence: true, uniqueness: { scope: :program_id, conditions: -> { where(deleted_at: nil) } }
  validates :date, presence: true

  def deleted_label
    "#{name} (#{program&.name})"
  end
end
