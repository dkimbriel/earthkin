class Family < ApplicationRecord
  has_many :parents, dependent: :destroy
  has_many :children, dependent: :destroy
  has_many :enrollment_applications, dependent: :nullify

  validates :name, presence: true

  def full_name
    "#{name} Family"
  end

  def primary_parent
    parents.order(:created_at).first
  end
end
