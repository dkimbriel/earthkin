class DriveFormPaymentPlansFromDb < ActiveRecord::Migration[7.0]
	# Replaces the hardcoded payment plan checkboxes in the Family Agreement
	# with the [[payment-plans]] marker, which expands from the program's
	# actual PaymentPlan records when the form is presented. Skips silently if
	# an admin has rewritten that section.

	class MigrationFormTemplate < ActiveRecord::Base
		self.table_name = 'form_templates'
	end

	HARDCODED_BLOCK = <<~TEXT.strip
		[[checkbox:plan_full|Option 1: Full Payment — one payment of $2,800, due August 1, 2026]]
		[[checkbox:plan_semester|Option 2: Semester Payments — two payments of $1,400 (Aug 1 and Jan 1)]]
		[[checkbox:plan_quarterly|Option 3: Quarterly Payments — four payments of $700 (Aug 1, Oct 1, Jan 1, April 1)]]
		[[checkbox:plan_monthly|Option 4: Monthly Payments — 10 payments of $280 due the first of each month beginning Aug 1 through May 1]]
		[[require-one:plan_full,plan_semester,plan_quarterly,plan_monthly|Please choose one payment plan option]]
	TEXT

	def up
		template = MigrationFormTemplate.find_by(key: 'family_agreement')
		return unless template&.body&.include?(HARDCODED_BLOCK)

		template.update!(body: template.body.sub(HARDCODED_BLOCK, '[[payment-plans]]'))
	end

	def down
		# Content edit — nothing sensible to revert to.
	end
end
