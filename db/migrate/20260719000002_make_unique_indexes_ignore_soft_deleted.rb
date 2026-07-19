# frozen_string_literal: true

# Make uniqueness apply only to live (non-deleted) rows, so a soft-deleted
# record no longer blocks reusing its value (most importantly users.email).
class MakeUniqueIndexesIgnoreSoftDeleted < ActiveRecord::Migration[7.2]
  def up
    remove_index :users, name: "index_users_on_email"
    add_index :users, :email, unique: true, name: "index_users_on_email",
              where: "deleted_at IS NULL"

    remove_index :email_templates, name: "index_email_templates_on_key"
    add_index :email_templates, :key, unique: true, name: "index_email_templates_on_key",
              where: "key IS NOT NULL AND deleted_at IS NULL"

    remove_index :enrollment_applications, name: "index_enrollment_applications_on_payment_selection_token"
    add_index :enrollment_applications, :payment_selection_token, unique: true,
              name: "index_enrollment_applications_on_payment_selection_token",
              where: "deleted_at IS NULL"

    remove_index :enrollment_form_signatures, name: "index_form_signatures_uniqueness"
    add_index :enrollment_form_signatures, %i[child_id form_template_id enrollment_application_id],
              unique: true, name: "index_form_signatures_uniqueness",
              where: "deleted_at IS NULL"

    remove_index :content_item_teachers, name: "index_content_item_teachers_on_content_item_id_and_teacher_id"
    add_index :content_item_teachers, %i[content_item_id teacher_id], unique: true,
              name: "index_content_item_teachers_on_content_item_id_and_teacher_id",
              where: "deleted_at IS NULL"

    remove_index :enrollment_payment_plans, name: "index_enrollment_payment_plans_on_program_enrollment_id"
    add_index :enrollment_payment_plans, :program_enrollment_id, unique: true,
              name: "index_enrollment_payment_plans_on_program_enrollment_id",
              where: "deleted_at IS NULL"
  end

  def down
    remove_index :users, name: "index_users_on_email"
    add_index :users, :email, unique: true, name: "index_users_on_email"

    remove_index :email_templates, name: "index_email_templates_on_key"
    add_index :email_templates, :key, unique: true, name: "index_email_templates_on_key",
              where: "(key IS NOT NULL)"

    remove_index :enrollment_applications, name: "index_enrollment_applications_on_payment_selection_token"
    add_index :enrollment_applications, :payment_selection_token, unique: true,
              name: "index_enrollment_applications_on_payment_selection_token"

    remove_index :enrollment_form_signatures, name: "index_form_signatures_uniqueness"
    add_index :enrollment_form_signatures, %i[child_id form_template_id enrollment_application_id],
              unique: true, name: "index_form_signatures_uniqueness"

    remove_index :content_item_teachers, name: "index_content_item_teachers_on_content_item_id_and_teacher_id"
    add_index :content_item_teachers, %i[content_item_id teacher_id], unique: true,
              name: "index_content_item_teachers_on_content_item_id_and_teacher_id"

    remove_index :enrollment_payment_plans, name: "index_enrollment_payment_plans_on_program_enrollment_id"
    add_index :enrollment_payment_plans, :program_enrollment_id, unique: true,
              name: "index_enrollment_payment_plans_on_program_enrollment_id"
  end
end
