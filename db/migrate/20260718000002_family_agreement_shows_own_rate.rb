class FamilyAgreementShowsOwnRate < ActiveRecord::Migration[7.0]
	# The Family Agreement's tuition section listed every payment plan (all
	# rate tiers) and hardcoded "$2,800". Switch it to [[tuition-plan]], which
	# resolves to each child's own tuition, selected plan, and due dates (on
	# the program's billing day) when the form is presented. Skips silently if
	# an admin has already customized this section.
	class MigrationFormTemplate < ActiveRecord::Base
		self.table_name = 'form_templates'
	end

	OLD_SENTENCE = 'Tuition amount is $2,800 for the Nature Preschool program. Tuition can be paid by check, cash, or Venmo. Parent has selected the following payment plan for tuition (check only one):'
	NEW_SENTENCE = 'Tuition can be paid by check, cash, or Venmo. Your tuition and selected payment plan for this enrollment are shown below.'

	def up
		template = MigrationFormTemplate.find_by(key: 'family_agreement')
		return unless template

		body = template.body.to_s
		return unless body.include?('[[payment-plans]]') && body.include?(OLD_SENTENCE)

		body = body.sub(OLD_SENTENCE, NEW_SENTENCE).sub('[[payment-plans]]', '[[tuition-plan]]')
		template.update!(body: body)
	end

	def down
		# Content edit — no meaningful revert.
	end
end
