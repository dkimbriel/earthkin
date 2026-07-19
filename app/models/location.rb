class Location < ApplicationRecord
  include SoftDeletable

  has_many :program_classes
  has_many :events, dependent: :nullify

  validates :name, presence: true, uniqueness: { conditions: -> { where(deleted_at: nil) } }
  validates :address, presence: true

  def full_address
    "#{name}, #{address}"
  end

  def deleted_label
    name
  end
end
