class FamilyAgreementStripeNotVenmo < ActiveRecord::Migration[7.0]
	# We've moved from Venmo to Stripe, so the Family Agreement's tuition line
	# should no longer offer Venmo. Targeted phrase swap; skips silently if an
	# admin has already reworded this section.
	class MigrationFormTemplate < ActiveRecord::Base
		self.table_name = 'form_templates'
	end

	OLD_PHRASE = 'check, cash, or Venmo'
	NEW_PHRASE = 'check, cash, or Stripe'

	def up
		template = MigrationFormTemplate.find_by(key: 'family_agreement')
		return unless template

		body = template.body.to_s
		return unless body.include?(OLD_PHRASE)

		template.update!(body: body.gsub(OLD_PHRASE, NEW_PHRASE))
	end

	def down
		template = MigrationFormTemplate.find_by(key: 'family_agreement')
		return unless template

		body = template.body.to_s
		return unless body.include?(NEW_PHRASE)

		template.update!(body: body.gsub(NEW_PHRASE, OLD_PHRASE))
	end
end
