class AddPaymentSelectionToEnrollmentApplications < ActiveRecord::Migration[7.2]
  def change
    add_column :enrollment_applications, :payment_selection_token, :string
    add_column :enrollment_applications, :payment_selection_token_created_at, :datetime
    add_reference :enrollment_applications, :selected_payment_plan, type: :uuid, foreign_key: { to_table: :payment_plans }, null: true

    add_index :enrollment_applications, :payment_selection_token, unique: true
  end
end
