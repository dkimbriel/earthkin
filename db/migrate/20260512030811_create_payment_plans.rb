class CreatePaymentPlans < ActiveRecord::Migration[7.2]
  def change
    create_table :payment_plans, id: :uuid do |t|
      t.references :program, type: :uuid, null: false, foreign_key: true

      t.string :name, null: false
      t.text :description
      t.integer :installment_count, null: false, default: 1
      t.decimal :total_amount, precision: 8, scale: 2, null: false
      t.decimal :installment_amount, precision: 8, scale: 2
      t.boolean :active, null: false, default: true
      t.integer :display_order, default: 0

      # JSON array of installment schedules
      # Example: [{month: 8, day: 1, amount: 2800}]
      t.jsonb :installment_schedule, default: []

      t.timestamps
    end

    add_index :payment_plans, [:program_id, :active]
    add_index :payment_plans, :display_order
  end
end
