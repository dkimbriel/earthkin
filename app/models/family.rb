class Family < ApplicationRecord
  include SoftDeletable

  has_many :parents, dependent: :destroy
  has_many :children, dependent: :destroy
  has_many :enrollment_applications, dependent: :nullify

  cascades_soft_delete :parents, :children

  validates :name, presence: true

  def full_name
    "#{name} Family"
  end

  def deleted_label
    full_name
  end

  def primary_parent
    parents.order(:created_at).first
  end
end
