class AddLocationToProgramClasses < ActiveRecord::Migration[7.2]
  def change
    add_reference :program_classes, :location, null: true, foreign_key: true
  end
end
