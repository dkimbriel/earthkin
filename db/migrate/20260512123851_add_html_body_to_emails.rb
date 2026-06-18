class AddHtmlBodyToEmails < ActiveRecord::Migration[7.2]
  def change
    add_column :emails, :html_body, :text
  end
end
