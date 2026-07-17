class ContentItem < ApplicationRecord
  VISIBILITIES = %w[all_staff specific_teachers].freeze
  CATEGORIES = %w[general manual curriculum form policy].freeze

  has_many :content_item_teachers, dependent: :destroy
  has_many :teachers, through: :content_item_teachers

  validates :title, presence: true
  validates :url, presence: true, format: { with: %r{\Ahttps?://}, message: 'must be a full link (https://...)' }
  validates :visibility, inclusion: { in: VISIBILITIES }

  # Items families can see in the parent portal.
  scope :for_families, -> { where(visible_to_families: true) }

  scope :visible_to, ->(user) {
    if user.admin?
      all
    else
      left_joins(:content_item_teachers)
        .where(visibility: 'all_staff')
        .or(left_joins(:content_item_teachers).where(content_item_teachers: { teacher_id: user.teacher&.id }))
        .distinct
    end
  }

  def as_json(_options = {})
    {
      id: id,
      title: title,
      url: url,
      description: description,
      category: category,
      visibility: visibility,
      visible_to_families: visible_to_families,
      teacher_ids: teachers.map(&:id),
      teacher_names: teachers.map(&:full_name),
      created_at: created_at
    }
  end
end
