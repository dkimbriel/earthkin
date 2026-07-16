class AddNoMedicationOption < ActiveRecord::Migration[7.0]
	# Families whose child needs no medication shouldn't have to fill out the
	# Medication Administration Form: a checkbox at the top waives all the
	# required fields so they can simply check it and sign. Skips silently if
	# an admin rewrote the intro paragraph.

	class MigrationFormTemplate < ActiveRecord::Base
		self.table_name = 'form_templates'
	end

	INTRO = 'This form must be completed for each medication your child needs while in our care. All medications must be in their original, labeled containers and given directly to staff. Medications are stored securely and administered according to the instructions below.'

	ADDITION = <<~TEXT.strip
		## No Medication Needed

		[[checkbox:no_medication|My child does not have any medication that needs to be administered while at Earthkin Nature School]]
		[[waive-required-if:no_medication]]

		If you checked the box above, you can skip the rest of this form and sign at the bottom.
	TEXT

	def up
		template = MigrationFormTemplate.find_by(key: 'medication_administration')
		return unless template
		return if template.body.include?('no_medication')
		return unless template.body.include?(INTRO)

		template.update!(body: template.body.sub(INTRO, "#{INTRO}\n\n#{ADDITION}"))
	end

	def down
		# Content edit — nothing sensible to revert to.
	end
end
