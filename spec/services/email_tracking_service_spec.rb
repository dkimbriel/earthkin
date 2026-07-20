require 'rails_helper'

RSpec.describe EmailTrackingService do
  describe '#send_email' do
    context 'with enrollment application' do
      let(:program) { create(:program, name: 'Forest Explorers') }
      let(:application) { create(:enrollment_application, program: program, parent_email: 'parent@example.com') }
      let(:service) { EmailTrackingService.new(application) }

      it 'creates an email record and delivers it immediately' do
        expect {
          service.send_email('EnrollmentMailer', 'enrollment_fee_request', [application.id])
        }.to change(Email, :count).by(1)
          .and change { ActionMailer::Base.deliveries.count }.by(1)

        email = Email.last
        expect(email.emailable).to eq(application)
        expect(email.mailer_class).to eq('EnrollmentMailer')
        expect(email.email_type).to eq('enrollment_fee_request')
        expect(email.recipient).to eq('parent@example.com')
        expect(email.subject).to include('Enrollment Fee')
        expect(email.status).to eq('sent')
        expect(email.sent_at).to be_present
        expect(email.html_body).to be_present
      end

      it 'creates an email record for enrollment confirmed' do
        email = service.send_email('EnrollmentMailer', 'enrollment_confirmed', [application.id])

        expect(email.subject).to include('Enrollment Confirmed')
      end

      it 'marks the email failed when the mailer raises, without raising' do
        allow(EnrollmentMailer).to receive(:enrollment_fee_request).and_raise(StandardError, 'Gmail is down')

        email = nil
        expect {
          email = service.send_email('EnrollmentMailer', 'enrollment_fee_request', [application.id])
        }.not_to change { ActionMailer::Base.deliveries.count }

        expect(email.status).to eq('failed')
        expect(email.failed_at).to be_present
        expect(email.error_message).to include('Gmail is down')
      end

      it 'marks the email failed for an unknown email type' do
        email = service.send_email('EnrollmentMailer', 'unknown_type', [])

        expect(email.subject).to eq('Nature Preschool Update')
        expect(email.status).to eq('failed')
      end
    end

    context 'when automated comms are muted on the application' do
      let(:program) { create(:program, name: 'Forest Explorers') }
      let(:application) do
        create(:enrollment_application, program: program, parent_email: 'parent@example.com', mute_automated_emails: true)
      end
      let(:service) { EmailTrackingService.new(application) }

      it 'skips automated emails without creating a record or delivering' do
        expect {
          result = service.send_email('EnrollmentMailer', 'enrollment_fee_request', [application.id])
          expect(result).to be_nil
        }.to change(Email, :count).by(0)
          .and change { ActionMailer::Base.deliveries.count }.by(0)
      end

      it 'still delivers a manual send (automated: false)' do
        expect {
          email = service.send_email('EnrollmentMailer', 'enrollment_fee_request', [application.id], {}, automated: false)
          expect(email.status).to eq('sent')
        }.to change(Email, :count).by(1)
          .and change { ActionMailer::Base.deliveries.count }.by(1)
      end
    end

    context 'with payment' do
      let(:family) { create(:family) }
      let(:parent) { create(:parent, family: family, email: 'parent@example.com') }
      let(:child) { create(:child, family: family) }
      let(:enrollment) { create(:program_enrollment, child: child) }
      let(:payment) { create(:payment, program_enrollment: enrollment) }
      let(:service) { EmailTrackingService.new(payment) }

      before { parent }

      it 'creates an email record for invoice and delivers it' do
        expect {
          email = service.send_email('PaymentMailer', 'invoice', [payment.id])

          expect(email.subject).to include('Payment Invoice')
          expect(email.recipient).to include('parent@example.com')
          expect(email.status).to eq('sent')
        }.to change { ActionMailer::Base.deliveries.count }.by(1)
      end

      it 'creates an email record for receipt and delivers it' do
        expect {
          email = service.send_email('PaymentMailer', 'receipt', [payment.id])

          expect(email.subject).to include('Payment Receipt')
          expect(email.recipient).to include('parent@example.com')
          expect(email.status).to eq('sent')
        }.to change { ActionMailer::Base.deliveries.count }.by(1)
      end
    end

    context 'with parent' do
      let(:family) { create(:family) }
      let(:parent) { create(:parent, family: family, email: 'parent@example.com') }
      let(:service) { EmailTrackingService.new(parent) }

      it 'creates an email record for welcome email and delivers it' do
        expect {
          email = service.send_email('ParentMailer', 'welcome_email', [parent.id, 'temp-password'])

          expect(email.subject).to include('Welcome to Earthkin')
          expect(email.recipient).to eq('parent@example.com')
          expect(email.status).to eq('sent')
        }.to change { ActionMailer::Base.deliveries.count }.by(1)
      end

      it 'creates an email record for application status update' do
        application = create(:enrollment_application)
        email = service.send_email('ParentMailer', 'application_status_update', [parent.id, application.id])

        expect(email.subject).to include('Enrollment Application')
      end
    end

    context 'with metadata' do
      let(:application) { create(:enrollment_application) }
      let(:service) { EmailTrackingService.new(application) }

      it 'stores metadata in email record' do
        metadata = { custom_field: 'value' }
        email = service.send_email('EnrollmentMailer', 'enrollment_fee_request', [application.id], metadata)

        expect(email.metadata).to eq({ 'custom_field' => 'value' })
      end
    end
  end
end
