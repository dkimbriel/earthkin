class CreatePayments < ActiveRecord::Migration[7.2]
  def change
    create_table :payments do |t|
      t.references :program_enrollment, null: false, foreign_key: true
      t.decimal :amount, precision: 8, scale: 2, null: false
      t.string :payment_method
      t.date :payment_date, null: false
      t.string :status, default: 'pending', null: false
      t.text :notes

      t.timestamps
    end
  end
end
