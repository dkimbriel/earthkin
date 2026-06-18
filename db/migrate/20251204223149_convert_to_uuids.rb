class ConvertToUuids < ActiveRecord::Migration[7.2]
  def up
    # Enable pgcrypto extension for gen_random_uuid()
    enable_extension 'pgcrypto'

    # Tables in order (parent tables first, then tables with foreign keys)
    # This ensures we can map old IDs to new UUIDs properly

    # Step 1: Add UUID columns to all tables
    tables_to_convert = %w[users families locations programs parents children program_classes program_enrollments payments]

    tables_to_convert.each do |table|
      add_column table, :uuid, :uuid, default: -> { "gen_random_uuid()" }, null: false
    end

    # Step 2: Add new UUID foreign key columns (before we drop the old ones)
    # parents
    add_column :parents, :family_uuid, :uuid
    add_column :parents, :user_uuid, :uuid

    # children
    add_column :children, :family_uuid, :uuid

    # program_classes
    add_column :program_classes, :program_uuid, :uuid
    add_column :program_classes, :location_uuid, :uuid

    # program_enrollments
    add_column :program_enrollments, :child_uuid, :uuid
    add_column :program_enrollments, :program_uuid, :uuid

    # payments
    add_column :payments, :program_enrollment_uuid, :uuid

    # Step 3: Populate new UUID foreign keys based on old relationships
    execute <<-SQL
      UPDATE parents SET family_uuid = families.uuid
      FROM families WHERE parents.family_id = families.id;

      UPDATE parents SET user_uuid = users.uuid
      FROM users WHERE parents.user_id = users.id;

      UPDATE children SET family_uuid = families.uuid
      FROM families WHERE children.family_id = families.id;

      UPDATE program_classes SET program_uuid = programs.uuid
      FROM programs WHERE program_classes.program_id = programs.id;

      UPDATE program_classes SET location_uuid = locations.uuid
      FROM locations WHERE program_classes.location_id = locations.id;

      UPDATE program_enrollments SET child_uuid = children.uuid
      FROM children WHERE program_enrollments.child_id = children.id;

      UPDATE program_enrollments SET program_uuid = programs.uuid
      FROM programs WHERE program_enrollments.program_id = programs.id;

      UPDATE payments SET program_enrollment_uuid = program_enrollments.uuid
      FROM program_enrollments WHERE payments.program_enrollment_id = program_enrollments.id;
    SQL

    # Step 4: Remove old foreign key constraints
    remove_foreign_key :parents, :families
    remove_foreign_key :parents, :users
    remove_foreign_key :children, :families
    remove_foreign_key :program_classes, :programs
    remove_foreign_key :program_classes, :locations
    remove_foreign_key :program_enrollments, :children
    remove_foreign_key :program_enrollments, :programs
    remove_foreign_key :payments, :program_enrollments

    # Step 5: Remove old foreign key columns and indexes
    remove_index :parents, :family_id
    remove_index :parents, :user_id
    remove_column :parents, :family_id
    remove_column :parents, :user_id

    remove_index :children, :family_id
    remove_column :children, :family_id

    remove_index :program_classes, :program_id
    remove_index :program_classes, :location_id
    remove_column :program_classes, :program_id
    remove_column :program_classes, :location_id

    remove_index :program_enrollments, :child_id
    remove_index :program_enrollments, :program_id
    remove_column :program_enrollments, :child_id
    remove_column :program_enrollments, :program_id

    remove_index :payments, :program_enrollment_id
    remove_column :payments, :program_enrollment_id

    # Step 6: Rename UUID foreign key columns to standard names
    rename_column :parents, :family_uuid, :family_id
    rename_column :parents, :user_uuid, :user_id

    rename_column :children, :family_uuid, :family_id

    rename_column :program_classes, :program_uuid, :program_id
    rename_column :program_classes, :location_uuid, :location_id

    rename_column :program_enrollments, :child_uuid, :child_id
    rename_column :program_enrollments, :program_uuid, :program_id

    rename_column :payments, :program_enrollment_uuid, :program_enrollment_id

    # Step 7: Convert primary keys from bigint to UUID
    tables_to_convert.each do |table|
      # Remove old primary key
      execute "ALTER TABLE #{table} DROP CONSTRAINT #{table}_pkey;"
      remove_column table, :id

      # Rename uuid to id and make it the primary key
      rename_column table, :uuid, :id
      execute "ALTER TABLE #{table} ADD PRIMARY KEY (id);"
    end

    # Step 8: Add NOT NULL constraints where appropriate and indexes
    change_column_null :parents, :family_id, false
    change_column_null :children, :family_id, false
    change_column_null :program_classes, :program_id, false
    change_column_null :program_enrollments, :child_id, false
    change_column_null :program_enrollments, :program_id, false
    change_column_null :payments, :program_enrollment_id, false

    # Step 9: Add indexes for foreign keys
    add_index :parents, :family_id
    add_index :parents, :user_id
    add_index :children, :family_id
    add_index :program_classes, :program_id
    add_index :program_classes, :location_id
    add_index :program_enrollments, :child_id
    add_index :program_enrollments, :program_id
    add_index :payments, :program_enrollment_id

    # Step 10: Re-add foreign key constraints
    add_foreign_key :parents, :families
    add_foreign_key :parents, :users
    add_foreign_key :children, :families
    add_foreign_key :program_classes, :programs
    add_foreign_key :program_classes, :locations
    add_foreign_key :program_enrollments, :children
    add_foreign_key :program_enrollments, :programs
    add_foreign_key :payments, :program_enrollments
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Cannot revert UUID conversion - data would be lost"
  end
end
