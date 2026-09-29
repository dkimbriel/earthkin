# frozen_string_literal: true

# The authorization a parent agrees to when turning on autopay. The exact text
# is saved on the enrollment's payment plan at the moment they agree.
#
# PLACEHOLDER WORDING: pending approval from the school (Sydney) before launch.
module AutopayTerms
	module_function

	def text(plan)
		child = plan.program_enrollment&.child
		program = plan.program_enrollment&.program

		<<~TERMS.squish
			I authorize Earthkin Nature School to automatically charge the card or bank account I
			provide for each remaining tuition installment of #{child&.first_name}'s enrollment in
			#{program&.name}, on each installment's due date and in the amount shown on the payment
			schedule. I'll receive a reminder email before each payment. If the schedule changes, the
			new amounts and dates apply. I can turn automatic payments off at any time from the Payments
			page of the family portal; payments already started can't be stopped.
		TERMS
	end
end
