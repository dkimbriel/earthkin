class AddPaymentTypeToPayments < ActiveRecord::Migration[7.2]
  def change
    add_column :payments, :payment_type, :string, default: 'tuition'
    # Types: enrollment_fee, tuition, other

    add_column :payments, :enrollment_payment_plan_id, :uuid
    add_column :payments, :installment_number, :integer

    add_foreign_key :payments, :enrollment_payment_plans
    add_index :payments, :payment_type
    add_index :payments, :enrollment_payment_plan_id
  end
end
