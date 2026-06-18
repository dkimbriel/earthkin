class CreateEnrollmentPaymentPlans < ActiveRecord::Migration[7.2]
  def change
    create_table :enrollment_payment_plans, id: :uuid do |t|
      t.references :program_enrollment, type: :uuid, null: false, foreign_key: true, index: { unique: true }
      t.references :payment_plan, type: :uuid, null: false, foreign_key: true

      t.decimal :total_amount, precision: 8, scale: 2, null: false
      t.decimal :enrollment_fee, precision: 8, scale: 2, null: false, default: 150.00
      t.boolean :enrollment_fee_paid, null: false, default: false
      t.datetime :enrollment_fee_paid_at

      # Snapshot of installment schedule at time of selection
      # Example: [{due_date: '2026-08-01', amount: 700, status: 'pending', paid_at: null}]
      t.jsonb :installments, default: []

      t.timestamps
    end
  end
end
