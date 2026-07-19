# frozen_string_literal: true

# Soft (restorable) deletes: a nullable deleted_at on every user-deletable table
# plus the cascade-only children that must be hidden/restored alongside a parent.
class AddDeletedAtForSoftDeletes < ActiveRecord::Migration[7.2]
  TABLES = %i[
    families parents children
    programs program_classes program_enrollments
    payment_plans payments teachers locations content_items
    users email_templates emails
    enrollment_applications enrollment_payment_plans
    program_teachers program_class_teachers content_item_teachers
    enrollment_form_signatures
  ].freeze

  def change
    TABLES.each do |table|
      add_column table, :deleted_at, :datetime
      add_index table, :deleted_at
    end
  end
end
