class AddCategoryToFormTemplates < ActiveRecord::Migration[7.0]
	def change
		# Form templates now cover two audiences: the enrollment paperwork
		# families sign, and staff documents (warnings, termination letters)
		# an employee signs. The category decides which {{tokens}} are valid
		# and keeps the two sets apart in the editor.
		add_column :form_templates, :category, :string, default: 'enrollment', null: false
		add_index :form_templates, :category
	end
end
