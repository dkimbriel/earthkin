class PaymentPlan < ApplicationRecord
  belongs_to :program
  has_many :enrollment_payment_plans, dependent: :restrict_with_error

  validates :name, presence: true
  validates :total_amount, presence: true, numericality: { greater_than: 0 }
  validates :installment_count, presence: true, numericality: { greater_than: 0 }

  scope :active, -> { where(active: true).order(:display_order) }

  before_save :calculate_installment_amount

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
end
