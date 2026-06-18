class CreateEmails < ActiveRecord::Migration[7.2]
  def change
    create_table :emails, id: :uuid do |t|
      t.string :emailable_type, null: false
      t.uuid :emailable_id, null: false
      t.string :mailer_class, null: false
      t.string :email_type, null: false
      t.string :recipient, null: false
      t.string :subject, null: false
      t.string :status, default: 'queued', null: false
      t.datetime :sent_at
      t.datetime :failed_at
      t.text :error_message
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :emails, [:emailable_type, :emailable_id]
    add_index :emails, :email_type
    add_index :emails, :status
    add_index :emails, :created_at
    add_index :emails, :mailer_class
  end
end
