require 'rails_helper'

RSpec.describe EmailTrackingService do
  before do
    allow(EnrollmentEmailJob).to receive(:perform_async)
  end

  describe '#queue_email' do
    context 'with enrollment application' do
      let(:program) { create(:program, name: 'Forest Explorers') }
      let(:application) { create(:enrollment_application, program: program, parent_email: 'parent@example.com') }
      let(:service) { EmailTrackingService.new(application) }

      it 'creates an email record for meeting invite' do
        expect {
          service.queue_email('EnrollmentMailer', 'meeting_invite', [application.id])
        }.to change(Email, :count).by(1)

        email = Email.last
        expect(email.emailable).to eq(application)
        expect(email.mailer_class).to eq('EnrollmentMailer')
        expect(email.email_type).to eq('meeting_invite')
        expect(email.recipient).to eq('parent@example.com')
        expect(email.subject).to include('Schedule A Meet-n-Greet')
        expect(email.status).to eq('queued')
      end

      it 'creates an email record for meeting scheduled' do
        email = service.queue_email('EnrollmentMailer', 'meeting_scheduled', [application.id])

        expect(email.subject).to include('Meet-n-Greet')
        expect(email.recipient).to eq('parent@example.com')
      end

      it 'creates an email record for enrollment fee request' do
        email = service.queue_email('EnrollmentMailer', 'enrollment_fee_request', [application.id])

        expect(email.subject).to include('Enrollment Fee')
      end

      it 'creates an email record for enrollment confirmed' do
        email = service.queue_email('EnrollmentMailer', 'enrollment_confirmed', [application.id])

        expect(email.subject).to include('Enrollment Confirmed')
      end

      it 'enqueues the email job' do
        expect(EnrollmentEmailJob).to receive(:perform_async)

        service.queue_email('EnrollmentMailer', 'meeting_invite', [application.id])
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

      it 'creates an email record for invoice' do
        email = service.queue_email('PaymentMailer', 'invoice', [payment.id])

        expect(email.subject).to eq('Payment Invoice')
        expect(email.recipient).to include('parent@example.com')
      end

      it 'creates an email record for receipt' do
        email = service.queue_email('PaymentMailer', 'receipt', [payment.id])

        expect(email.subject).to eq('Payment Receipt')
        expect(email.recipient).to include('parent@example.com')
      end
    end

    context 'with parent' do
      let(:family) { create(:family) }
      let(:parent) { create(:parent, family: family, email: 'parent@example.com') }
      let(:service) { EmailTrackingService.new(parent) }

      it 'creates an email record for welcome email' do
        email = service.queue_email('ParentMailer', 'welcome_email', [parent.id])

        expect(email.subject).to include('Welcome to Earthkin')
        expect(email.recipient).to eq('parent@example.com')
      end

      it 'creates an email record for application status update' do
        email = service.queue_email('ParentMailer', 'application_status_update', [parent.id])

        expect(email.subject).to include('Enrollment Application')
      end
    end

    context 'with unknown email type' do
      let(:application) { create(:enrollment_application) }
      let(:service) { EmailTrackingService.new(application) }

      it 'uses default subject' do
        email = service.queue_email('SomeMailer', 'unknown_type', [])

        expect(email.subject).to eq('Nature Preschool Update')
      end
    end

    context 'with metadata' do
      let(:application) { create(:enrollment_application) }
      let(:service) { EmailTrackingService.new(application) }

      it 'stores metadata in email record' do
        metadata = { custom_field: 'value' }
        email = service.queue_email('EnrollmentMailer', 'meeting_invite', [], metadata)

        expect(email.metadata).to eq({ 'custom_field' => 'value' })
      end
    end
  end
end
