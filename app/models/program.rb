class Program < ApplicationRecord
  include SoftDeletable

  has_many :program_classes, -> { order(:date, :start_time) }, dependent: :destroy
  has_many :locations, -> { distinct }, through: :program_classes
  has_many :program_enrollments, dependent: :destroy
  has_many :children, through: :program_enrollments
  has_many :program_teachers, dependent: :destroy
  has_many :teachers, through: :program_teachers
  has_many :payment_plans, dependent: :destroy
  has_many :enrollment_applications, dependent: :destroy

  cascades_soft_delete :program_classes, :program_enrollments, :payment_plans,
                       :program_teachers, :enrollment_applications

  validates :name, presence: true
  validates :start_date, presence: true
  validates :end_date, presence: true

  scope :current, -> { where('start_date <= ? AND end_date >= ?', Date.current, Date.current) }
  scope :upcoming, -> { where('start_date > ?', Date.current) }

  def enrolled_count
    program_enrollments.where(status: 'confirmed').count
  end

  def pending_count
    program_enrollments.where(status: 'pending').count
  end

  def revenue_per_class
    program_enrollments.where(status: 'confirmed').sum(:rate_per_class)
  end

  def duration_in_months
    return nil unless start_date && end_date
    ((end_date.year * 12 + end_date.month) - (start_date.year * 12 + start_date.month))
  end

  def formatted_schedule
    return nil unless class_days.present?
    time_range = formatted_time_range
    time_range ? "#{class_days}, #{time_range}" : class_days
  end

  def formatted_time_range
    return nil unless start_time.present? && end_time.present?
    "#{format_time(start_time)}–#{format_time(end_time)}"
  end

  def tuition_amount
    payment_plans.active.first&.total_amount
  end

  def deleted_label
    name
  end

  private

  def format_time(time)
    return nil unless time
    time.strftime('%l:%M %p').strip
  end
end
