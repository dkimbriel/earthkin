# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2026_07_10_000002) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pgcrypto"
  enable_extension "plpgsql"

  create_table "active_storage_attachments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.uuid "record_id", null: false
    t.uuid "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "children", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "family_id", null: false
    t.index ["family_id"], name: "index_children_on_family_id"
  end

  create_table "content_item_teachers", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "content_item_id", null: false
    t.uuid "teacher_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["content_item_id", "teacher_id"], name: "index_content_item_teachers_on_content_item_id_and_teacher_id", unique: true
    t.index ["content_item_id"], name: "index_content_item_teachers_on_content_item_id"
    t.index ["teacher_id"], name: "index_content_item_teachers_on_teacher_id"
  end

  create_table "content_items", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "title", null: false
    t.string "url", null: false
    t.text "description"
    t.string "category", default: "general", null: false
    t.string "visibility", default: "all_staff", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "emails", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "emailable_type", null: false
    t.uuid "emailable_id", null: false
    t.string "mailer_class", null: false
    t.string "email_type", null: false
    t.string "recipient", null: false
    t.string "subject", null: false
    t.string "status", default: "queued", null: false
    t.datetime "sent_at"
    t.datetime "failed_at"
    t.text "error_message"
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "html_body"
    t.index ["created_at"], name: "index_emails_on_created_at"
    t.index ["email_type"], name: "index_emails_on_email_type"
    t.index ["emailable_type", "emailable_id"], name: "index_emails_on_emailable_type_and_emailable_id"
    t.index ["mailer_class"], name: "index_emails_on_mailer_class"
    t.index ["status"], name: "index_emails_on_status"
  end

  create_table "enrollment_applications", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "family_id"
    t.uuid "program_id", null: false
    t.uuid "child_id"
    t.uuid "program_enrollment_id"
    t.string "status", default: "submitted", null: false
    t.string "parent_first_name"
    t.string "parent_last_name"
    t.string "parent_email"
    t.string "parent_phone"
    t.string "child_first_name"
    t.string "child_last_name"
    t.date "child_date_of_birth"
    t.text "why_interested"
    t.text "child_description"
    t.text "special_needs"
    t.text "dietary_restrictions"
    t.text "previous_school_experience"
    t.text "parent_expectations"
    t.text "admin_notes"
    t.datetime "submitted_at"
    t.datetime "reviewed_at"
    t.datetime "declined_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "payment_selection_token"
    t.datetime "payment_selection_token_created_at"
    t.uuid "selected_payment_plan_id"
    t.string "child_race_ethnicity"
    t.string "parent2_first_name"
    t.string "parent2_last_name"
    t.string "is_local"
    t.string "local_area"
    t.string "referral_source"
    t.jsonb "agreements", default: {}
    t.string "parent2_email"
    t.string "parent2_phone"
    t.decimal "custom_enrollment_fee", precision: 8, scale: 2
    t.decimal "custom_tuition_amount", precision: 8, scale: 2
    t.index ["child_id"], name: "index_enrollment_applications_on_child_id"
    t.index ["family_id"], name: "index_enrollment_applications_on_family_id"
    t.index ["parent_email"], name: "index_enrollment_applications_on_parent_email"
    t.index ["payment_selection_token"], name: "index_enrollment_applications_on_payment_selection_token", unique: true
    t.index ["program_enrollment_id"], name: "index_enrollment_applications_on_program_enrollment_id"
    t.index ["program_id"], name: "index_enrollment_applications_on_program_id"
    t.index ["selected_payment_plan_id"], name: "index_enrollment_applications_on_selected_payment_plan_id"
    t.index ["status"], name: "index_enrollment_applications_on_status"
  end

  create_table "enrollment_payment_plans", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "program_enrollment_id", null: false
    t.uuid "payment_plan_id", null: false
    t.decimal "total_amount", precision: 8, scale: 2, null: false
    t.decimal "enrollment_fee", precision: 8, scale: 2, default: "150.0", null: false
    t.boolean "enrollment_fee_paid", default: false, null: false
    t.datetime "enrollment_fee_paid_at"
    t.jsonb "installments", default: []
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["payment_plan_id"], name: "index_enrollment_payment_plans_on_payment_plan_id"
    t.index ["program_enrollment_id"], name: "index_enrollment_payment_plans_on_program_enrollment_id", unique: true
  end

  create_table "events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "eventable_type", null: false
    t.uuid "eventable_id", null: false
    t.uuid "location_id"
    t.string "event_type", null: false
    t.string "title"
    t.text "description"
    t.datetime "scheduled_at"
    t.datetime "completed_at"
    t.datetime "cancelled_at"
    t.string "status", default: "scheduled", null: false
    t.text "notes"
    t.text "outcome_notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "proposed_dates", default: []
    t.string "confirmation_token"
    t.index ["confirmation_token"], name: "index_events_on_confirmation_token", unique: true
    t.index ["event_type"], name: "index_events_on_event_type"
    t.index ["eventable_type", "eventable_id"], name: "index_events_on_eventable"
    t.index ["location_id"], name: "index_events_on_location_id"
    t.index ["scheduled_at"], name: "index_events_on_scheduled_at"
    t.index ["status"], name: "index_events_on_status"
  end

  create_table "families", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "gmail_integrations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "email", null: false
    t.text "access_token"
    t.text "refresh_token"
    t.datetime "token_expires_at"
    t.string "status", default: "connected", null: false
    t.uuid "connected_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["connected_by_id"], name: "index_gmail_integrations_on_connected_by_id"
  end

  create_table "locations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name"
    t.text "address"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "parents", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
    t.string "email"
    t.string "phone"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "family_id", null: false
    t.uuid "user_id"
    t.index ["family_id"], name: "index_parents_on_family_id"
    t.index ["user_id"], name: "index_parents_on_user_id"
  end

  create_table "payment_plans", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "program_id", null: false
    t.string "name", null: false
    t.text "description"
    t.integer "installment_count", default: 1, null: false
    t.decimal "total_amount", precision: 8, scale: 2, null: false
    t.decimal "installment_amount", precision: 8, scale: 2
    t.boolean "active", default: true, null: false
    t.integer "display_order", default: 0
    t.jsonb "installment_schedule", default: []
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["display_order"], name: "index_payment_plans_on_display_order"
    t.index ["program_id", "active"], name: "index_payment_plans_on_program_id_and_active"
    t.index ["program_id"], name: "index_payment_plans_on_program_id"
  end

  create_table "payments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.decimal "amount", precision: 8, scale: 2, null: false
    t.string "payment_method"
    t.date "payment_date", null: false
    t.string "status", default: "pending", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "program_enrollment_id", null: false
    t.string "payment_type", default: "tuition"
    t.uuid "enrollment_payment_plan_id"
    t.integer "installment_number"
    t.index ["enrollment_payment_plan_id"], name: "index_payments_on_enrollment_payment_plan_id"
    t.index ["payment_type"], name: "index_payments_on_payment_type"
    t.index ["program_enrollment_id"], name: "index_payments_on_program_enrollment_id"
  end

  create_table "program_class_teachers", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "program_class_id", null: false
    t.uuid "teacher_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["program_class_id"], name: "index_program_class_teachers_on_program_class_id"
    t.index ["teacher_id"], name: "index_program_class_teachers_on_teacher_id"
  end

  create_table "program_classes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name"
    t.date "date"
    t.time "start_time"
    t.time "end_time"
    t.string "location"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "program_id", null: false
    t.uuid "location_id"
    t.index ["location_id"], name: "index_program_classes_on_location_id"
    t.index ["program_id"], name: "index_program_classes_on_program_id"
  end

  create_table "program_enrollments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "status", default: "pending", null: false
    t.decimal "rate_per_class", precision: 8, scale: 2
    t.datetime "enrolled_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "child_id", null: false
    t.uuid "program_id", null: false
    t.date "cancelled_at"
    t.uuid "enrollment_application_id"
    t.string "workflow_status", default: "application_submitted"
    t.index ["child_id"], name: "index_program_enrollments_on_child_id"
    t.index ["enrollment_application_id"], name: "index_program_enrollments_on_enrollment_application_id"
    t.index ["program_id"], name: "index_program_enrollments_on_program_id"
    t.index ["workflow_status"], name: "index_program_enrollments_on_workflow_status"
  end

  create_table "program_teachers", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "program_id", null: false
    t.uuid "teacher_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["program_id"], name: "index_program_teachers_on_program_id"
    t.index ["teacher_id"], name: "index_program_teachers_on_teacher_id"
  end

  create_table "programs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.date "start_date"
    t.date "end_date"
    t.integer "capacity"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "enrollment_fee", precision: 10, scale: 2, default: "150.0"
    t.string "class_days"
    t.time "start_time"
    t.time "end_time"
  end

  create_table "teachers", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
    t.string "email"
    t.string "phone"
    t.text "bio"
    t.uuid "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_teachers_on_user_id"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "super_admin", default: false, null: false
    t.string "role", default: "parent", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "children", "families"
  add_foreign_key "content_item_teachers", "content_items"
  add_foreign_key "content_item_teachers", "teachers"
  add_foreign_key "enrollment_applications", "children"
  add_foreign_key "enrollment_applications", "families"
  add_foreign_key "enrollment_applications", "payment_plans", column: "selected_payment_plan_id"
  add_foreign_key "enrollment_applications", "program_enrollments"
  add_foreign_key "enrollment_applications", "programs"
  add_foreign_key "enrollment_payment_plans", "payment_plans"
  add_foreign_key "enrollment_payment_plans", "program_enrollments"
  add_foreign_key "events", "locations"
  add_foreign_key "gmail_integrations", "users", column: "connected_by_id"
  add_foreign_key "parents", "families"
  add_foreign_key "parents", "users"
  add_foreign_key "payment_plans", "programs"
  add_foreign_key "payments", "enrollment_payment_plans"
  add_foreign_key "payments", "program_enrollments"
  add_foreign_key "program_class_teachers", "program_classes"
  add_foreign_key "program_class_teachers", "teachers"
  add_foreign_key "program_classes", "locations"
  add_foreign_key "program_classes", "programs"
  add_foreign_key "program_enrollments", "children"
  add_foreign_key "program_enrollments", "enrollment_applications"
  add_foreign_key "program_enrollments", "programs"
  add_foreign_key "program_teachers", "programs"
  add_foreign_key "program_teachers", "teachers"
  add_foreign_key "teachers", "users"
end
