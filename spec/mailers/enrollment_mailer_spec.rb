require 'rails_helper'

RSpec.describe EnrollmentMailer, type: :mailer do
  describe 'meeting_invite' do
    let(:application) { create(:enrollment_application) }
    let(:location) { create(:location) }
    let(:event) do
      create(:event, :pending_selection,
        eventable: application,
        event_type: 'meet_and_greet',
        location: location
      )
    end
    let(:mail) { EnrollmentMailer.meeting_invite(event.id, 'http://localhost:3000') }

    it 'renders the headers' do
      expect(mail.subject).to include('Schedule A Meet-n-Greet')
      expect(mail.to).to eq([application.parent_email])
    end

    it 'renders the body with date options' do
      expect(mail.body.encoded).to include(location.name)
      expect(mail.body.encoded).to include('Schedule A Meet-n-Greet')
      expect(mail.body.encoded).to include(event.confirmation_token)
    end
  end

  describe 'meeting_scheduled' do
    let(:application) { create(:enrollment_application) }
    let(:location) { create(:location) }
    let(:event) do
      create(:event,
        eventable: application,
        event_type: 'meet_and_greet',
        location: location,
        scheduled_at: 1.week.from_now
      )
    end
    let(:mail) { EnrollmentMailer.meeting_scheduled(event.id) }

    it 'renders the headers' do
      expect(mail.subject).to include('Meet-n-Greet Scheduled')
      expect(mail.to).to eq([application.parent_email])
    end

    it 'renders the body with event details' do
      expect(mail.body.encoded).to include(location.name)
      expect(mail.body.encoded).to include('selecting a date for the Earthkin Nature School Meet-n-Greet')
    end

    it 'points families at the Family Handbook before the meeting' do
      expect(mail.body.encoded).to include('Family Handbook')
      expect(mail.body.encoded).to include('come ready with questions')
    end
  end

  describe 'enrollment_fee_request' do
    let(:application) { create(:enrollment_application) }
    let(:mail) { EnrollmentMailer.enrollment_fee_request(application.id) }

    it 'renders the headers' do
      expect(mail.subject).to include('Next Steps: Enrollment Fee')
      expect(mail.to).to eq([application.parent_email])
    end

    it 'renders the body with fee amount' do
      expect(mail.body.encoded).to include('$150')
      expect(mail.body.encoded).to include('enrollment fee')
    end
  end
end
