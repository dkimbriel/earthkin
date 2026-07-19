class Teacher < ApplicationRecord
  include SoftDeletable

  belongs_to :user, optional: true
  has_one_attached :avatar
  has_many :program_teachers, dependent: :destroy
  has_many :programs, through: :program_teachers
  has_many :program_class_teachers, dependent: :destroy
  has_many :program_classes, through: :program_class_teachers

  cascades_soft_delete :program_teachers, :program_class_teachers

  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :email, presence: true

  before_save :normalize_phone

  def full_name
    "#{first_name} #{last_name}"
  end

  def deleted_label
    full_name
  end

  def avatar_url
    return nil unless avatar.attached?

    Rails.application.routes.url_helpers.rails_blob_url(avatar, only_path: true)
  end

  private

  def normalize_phone
    self.phone = phone.gsub(/\D/, '') if phone.present?
  end
end
