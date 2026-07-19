class PaymentPlan < ApplicationRecord
  include SoftDeletable

  belongs_to :program
  has_many :enrollment_payment_plans, dependent: :restrict_with_error

  validates :name, presence: true
  validates :total_amount, presence: true, numericality: { greater_than: 0 }
  validates :installment_count, presence: true, numericality: { greater_than: 0 }

  scope :active, -> { where(active: true).order(:display_order) }

  def deleted_label
    "#{name} — #{program&.name}"
  end

  before_save :calculate_installment_amount
  before_create :assign_display_order

  # Generate installment schedule starting from a given date
  # Returns array of hashes with { due_date:, amount: }
  def generate_schedule(start_date)
    start_date = Date.parse(start_date.to_s) if start_date.is_a?(String)
    return [] if installment_count.nil? || installment_count < 1

    schedule = []
    installment_count.times do |i|
      due_date = start_date >> i # Add i months
      schedule << {
        'due_date' => due_date.to_s,
        'amount' => installment_amount.to_f,
        'status' => 'pending'
      }
    end
    schedule
  end

  # Generate a preview schedule for display (month/day format for UI)
  def preview_schedule(start_date)
    generate_schedule(start_date).map do |installment|
      date = Date.parse(installment['due_date'])
      {
        'month' => date.month,
        'day' => date.day,
        'amount' => installment['amount']
      }
    end
  end

  private

  def calculate_installment_amount
    self.installment_amount = total_amount / installment_count if installment_count > 0
  end

  # New plans join the end of the list. The first active plan is treated as
  # the program's standard rate (default tuition in emails and the public
  # enrollment page), so a newly added discount plan must not jump ahead.
  def assign_display_order
    return if display_order.present? && display_order.positive?

    self.display_order = (self.class.where(program: program).maximum(:display_order) || 0) + 1
  end
end
