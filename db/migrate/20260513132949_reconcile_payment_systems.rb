class ReconcilePaymentSystems < ActiveRecord::Migration[7.2]
  def change
    # Make rate_per_class optional (deprecating per-class billing in favor of payment plans)
    change_column_null :program_enrollments, :rate_per_class, true
    change_column_default :program_enrollments, :rate_per_class, nil
  end
end
