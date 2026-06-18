require 'rails_helper'

RSpec.describe EnrollmentEmailJob, type: :job do
  let(:application) { create(:enrollment_application) }
  let(:email) { create(:email, emailable: application) }

  describe '#perform' do
    let(:body_double) { double(decoded: '<html><body>Test email content</body></html>') }
    let(:mailer_double) { double('mailer') }

    before do
      allow(mailer_double).to receive(:deliver_now)
      allow(mailer_double).to receive(:html_part).and_return(nil)
      allow(mailer_double).to receive(:content_type).and_return('text/html')
      allow(mailer_double).to receive(:body).and_return(body_double)
    end

    context 'when email is sent successfully' do
      it 'delivers the email' do
        allow(EnrollmentMailer).to receive(:enrollment_fee_request).and_return(mailer_double)

        job = EnrollmentEmailJob.new
        job.perform('enrollment_fee_request', application.id, email.id)

        expect(EnrollmentMailer).to have_received(:enrollment_fee_request).with(application.id)
        expect(mailer_double).to have_received(:deliver_now)
      end

      it 'marks the email as sent and stores HTML body' do
        allow(EnrollmentMailer).to receive(:enrollment_fee_request).and_return(mailer_double)

        job = EnrollmentEmailJob.new
        job.perform('enrollment_fee_request', application.id, email.id)

        email.reload
        expect(email.status).to eq('sent')
        expect(email.sent_at).to be_present
        expect(email.html_body).to be_present
      end
    end

    context 'when email delivery fails' do
      it 'marks the email as failed' do
        allow(EnrollmentMailer).to receive(:enrollment_fee_request)
          .and_raise(StandardError.new('SMTP error'))

        job = EnrollmentEmailJob.new

        expect {
          job.perform('enrollment_fee_request', application.id, email.id)
        }.to raise_error(StandardError)

        email.reload
        expect(email.status).to eq('failed')
        expect(email.failed_at).to be_present
        expect(email.error_message).to include('SMTP error')
      end

      it 're-raises the error for Sidekiq retry logic' do
        allow(EnrollmentMailer).to receive(:enrollment_fee_request)
          .and_raise(StandardError.new('SMTP error'))

        job = EnrollmentEmailJob.new

        expect {
          job.perform('enrollment_fee_request', application.id, email.id)
        }.to raise_error(StandardError, 'SMTP error')
      end
    end

    context 'when email_id is not provided' do
      it 'sends email without tracking' do
        allow(EnrollmentMailer).to receive(:enrollment_fee_request).and_return(mailer_double)

        job = EnrollmentEmailJob.new
        job.perform('enrollment_fee_request', application.id, nil)

        expect(EnrollmentMailer).to have_received(:enrollment_fee_request).with(application.id)
      end
    end

    context 'with different mailer methods' do
      let(:event) { create(:event, eventable: application, event_type: 'meet_and_greet', scheduled_at: 1.week.from_now) }

      it 'calls meeting_scheduled method' do
        allow(EnrollmentMailer).to receive(:meeting_scheduled).and_return(mailer_double)

        job = EnrollmentEmailJob.new
        job.perform('meeting_scheduled', event.id, email.id)

        expect(EnrollmentMailer).to have_received(:meeting_scheduled).with(event.id)
      end

      it 'calls enrollment_fee_request method' do
        allow(EnrollmentMailer).to receive(:enrollment_fee_request).and_return(mailer_double)

        job = EnrollmentEmailJob.new
        job.perform('enrollment_fee_request', application.id, email.id)

        expect(EnrollmentMailer).to have_received(:enrollment_fee_request).with(application.id)
      end
    end

    context 'with multiple arguments' do
      it 'passes all arguments to the mailer' do
        allow(EnrollmentMailer).to receive(:enrollment_invite).and_return(mailer_double)

        job = EnrollmentEmailJob.new
        job.perform('enrollment_invite', application.id, 'http://example.com', email.id)

        expect(EnrollmentMailer).to have_received(:enrollment_invite)
          .with(application.id, 'http://example.com')
      end
    end
  end
end
