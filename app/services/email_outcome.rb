# frozen_string_literal: true

# Describes what actually happened to an email the portal tried to send, so the
# admin who pressed the button gets told the truth.
#
# EmailTrackingService deliberately records delivery failures on the Email row
# instead of raising (a mail outage must not abort a workflow), and returns nil
# when it suppressed the send because the family has automated emails muted. A
# caller that assumes success is therefore wrong in two different ways, both of
# them silent: staff believed a meet-and-greet invite had gone out for a week
# while the family sat waiting to hear back.
module EmailOutcome
	SUPPRESSED_NOTE = [
		'was NOT sent: automated emails are muted for this family.',
		'Unmute them, or send it by hand from the Communications tab.'
	].join(' ').freeze

	# `email` is whatever EmailTrackingService#send_email returned: nil when the
	# send was suppressed, otherwise the record carrying its own status.
	def self.classify(email)
		return :suppressed if email.nil?
		return :sent if email.status == 'sent'

		:failed
	end

	# A message for the admin, plus a machine-readable status the UI styles on
	# (green for sent, amber for anything that did not reach the parent).
	def self.describe(label, outcome, email = nil)
		case outcome
		when :sent then { message: "#{label} sent to parent", email_status: 'sent' }
		when :suppressed then { message: "#{label} #{SUPPRESSED_NOTE}", email_status: 'suppressed' }
		when :failed then failure(label, email)
		else { message: 'No email was sent.', email_status: 'not_attempted' }
		end
	end

	def self.failure(label, email)
		{ message: "#{label} could NOT be sent: #{first_line(email&.error_message)}", email_status: 'failed' }
	end

	def self.first_line(error)
		error.to_s.lines.first.to_s.strip.presence || 'unknown error'
	end
end
