require 'rails_helper'

RSpec.describe 'MeetingConfirmations', type: :request do
  let(:program) { create(:program) }
  let(:location) { create(:location) }
  let(:application) { create(:enrollment_application, program: program) }
  let(:proposed_dates) do
    [
      1.week.from_now.change(hour: 10),
      1.week.from_now.change(hour: 14),
      2.weeks.from_now.change(hour: 10)
    ].map(&:iso8601)
  end
  let(:event) do
    create(:event,
      eventable: application,
      location: location,
      event_type: 'meet_and_greet',
      status: 'pending_selection',
      proposed_dates: proposed_dates,
      confirmation_token: SecureRandom.urlsafe_base64(24)
    )
  end

  describe 'GET /meetings/:token/confirm' do
    context 'with valid token and date' do
      it 'renders the confirmation page' do
        selected_date = Time.zone.parse(proposed_dates.first).to_i

        get "/meetings/#{event.confirmation_token}/confirm", params: { date: selected_date }

        expect(response).to have_http_status(:success)
        expect(response.body).to include('Confirm Your Meet-n-Greet')
        expect(response.body).to include(application.parent_first_name)
      end
    end

    context 'with invalid token' do
      it 'returns not found' do
        get '/meetings/invalid-token/confirm', params: { date: Time.current.to_i }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with invalid date' do
      it 'renders invalid date page' do
        invalid_date = 3.weeks.from_now.to_i

        get "/meetings/#{event.confirmation_token}/confirm", params: { date: invalid_date }

        expect(response).to have_http_status(:success)
        expect(response.body).to include('Invalid Date')
      end
    end

    context 'when already confirmed' do
      before do
        event.update!(status: 'scheduled', scheduled_at: Time.zone.parse(proposed_dates.first))
      end

      it 'renders already scheduled page' do
        get "/meetings/#{event.confirmation_token}/confirm", params: { date: Time.zone.parse(proposed_dates.first).to_i }

        expect(response).to have_http_status(:success)
        expect(response.body).to include('Meeting Already Scheduled')
      end
    end
  end

  describe 'POST /meetings/:token/confirm' do
    context 'with valid date' do
      it 'confirms the meeting date' do
        selected_date = Time.zone.parse(proposed_dates.first).to_i

        expect {
          post "/meetings/#{event.confirmation_token}/confirm", params: { date: selected_date }
        }.to change { event.reload.status }.from('pending_selection').to('scheduled')

        expect(response).to have_http_status(:success)
        expect(response.body).to include('Your Meet-n-Greet is Confirmed')
        expect(event.reload.scheduled_at).to be_present
      end

      it 'updates application status to meeting_scheduled' do
        selected_date = Time.zone.parse(proposed_dates.first).to_i

        post "/meetings/#{event.confirmation_token}/confirm", params: { date: selected_date }

        expect(application.reload.status).to eq('meeting_scheduled')
      end
    end

    context 'with invalid date' do
      it 'redirects back to confirmation page' do
        invalid_date = 3.weeks.from_now.to_i

        post "/meetings/#{event.confirmation_token}/confirm", params: { date: invalid_date }

        expect(response).to have_http_status(:redirect)
        expect(event.reload.status).to eq('pending_selection')
      end
    end

    context 'when already confirmed' do
      before do
        event.update!(status: 'scheduled', scheduled_at: Time.zone.parse(proposed_dates.first))
      end

      it 'renders already scheduled page' do
        post "/meetings/#{event.confirmation_token}/confirm", params: { date: Time.zone.parse(proposed_dates.first).to_i }

        expect(response).to have_http_status(:success)
        expect(response.body).to include('Meeting Already Scheduled')
      end
    end
  end
end
