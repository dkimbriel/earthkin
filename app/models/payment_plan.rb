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
  #
  # `total` is what the family actually owes, which differs from the plan's
  # standard amount when the application carries custom (e.g. prorated)
  # tuition. It is split to the cent so the schedule sums exactly to the
  # total; any leftover cents land on the first installment.
  def generate_schedule(start_date, total: total_amount)
    start_date = Date.parse(start_date.to_s) if start_date.is_a?(String)
    return [] if installment_count.nil? || installment_count < 1

    amounts = self.class.split_evenly(total, installment_count)
    amounts.each_with_index.map do |amount, i|
      {
        'due_date' => (start_date >> i).to_s, # Add i months
        'amount' => amount.to_f,
        'status' => 'pending'
      }
    end
  end

  # Split `total` into `count` amounts that sum exactly to it, with the
  # remainder cents on the first: 2460 / 9 => [273.36, 273.33 x 8].
  def self.split_evenly(total, count)
    cents = (BigDecimal(total.to_s) * 100).round.to_i
    base, remainder = cents.divmod(count)
    Array.new(count) { |i| BigDecimal(base + (i.zero? ? remainder : 0)) / 100 }
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
