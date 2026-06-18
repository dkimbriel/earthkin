class Location < ApplicationRecord
  has_many :program_classes
  has_many :events, dependent: :nullify

  validates :name, presence: true, uniqueness: true
  validates :address, presence: true

  def full_address
    "#{name}, #{address}"
  end
end
