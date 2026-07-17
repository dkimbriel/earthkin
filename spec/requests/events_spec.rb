require 'rails_helper'

RSpec.describe 'Api::Events', type: :request do
  let(:user) { create(:user) }
  let(:application) { create(:enrollment_application) }
  let(:location) { create(:location) }

  before { sign_in user }

  describe 'GET /api/events' do
    before do
      create(:event, eventable: application, event_type: 'meet_and_greet', location: location)
      create(:event, eventable: application, event_type: 'orientation', status: 'completed', location: location)
    end

    it 'returns all events' do
      get '/api/events'
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json.length).to eq(2)
    end

    it 'filters by status' do
      get '/api/events', params: { status: 'completed' }
      json = JSON.parse(response.body)
      expect(json.length).to eq(1)
      expect(json.first['status']).to eq('completed')
    end

    it 'filters by event_type' do
      get '/api/events', params: { event_type: 'meet_and_greet' }
      json = JSON.parse(response.body)
      expect(json.length).to eq(1)
      expect(json.first['event_type']).to eq('meet_and_greet')
    end

    it 'filters by eventable' do
      other_application = create(:enrollment_application)
      create(:event, eventable: other_application)

      get '/api/events', params: {
        eventable_type: 'EnrollmentApplication',
        eventable_id: application.id
      }
      json = JSON.parse(response.body)
      expect(json.length).to eq(2)
    end

    it 'includes associated records' do
      get '/api/events'
      json = JSON.parse(response.body)
      expect(json.first).to have_key('eventable')
      expect(json.first).to have_key('location')
    end
  end

  describe 'GET /api/events/:id' do
    let(:event) { create(:event, eventable: application) }

    it 'returns the event' do
      get "/api/events/#{event.id}"
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json['id']).to eq(event.id)
    end
  end

  describe 'POST /api/events' do
    context 'when creating a meet_and_greet for enrollment application' do
      let(:service) { instance_double(EnrollmentWorkflowService) }
      let(:event) { create(:event, eventable: application, event_type: 'meet_and_greet') }

      before do
        allow(EnrollmentWorkflowService).to receive(:new).with(application).and_return(service)
        allow(service).to receive(:schedule_meeting).and_return(event)
      end

      it 'uses the workflow service' do
        post '/api/events', params: {
          event: {
            event_type: 'meet_and_greet',
            eventable_type: 'EnrollmentApplication',
            eventable_id: application.id,
            location_id: location.id,
            scheduled_at: 1.week.from_now.iso8601,
            notes: 'Initial meeting'
          }
        }

        expect(response).to have_http_status(:created)
        expect(service).to have_received(:schedule_meeting)
      end
    end

    context 'when creating a standalone school event' do
      it 'creates a published event with no eventable' do
        expect {
          post '/api/events', params: {
            event: {
              event_type: 'open_house',
              title: 'Fall Open House',
              scheduled_at: 2.weeks.from_now.iso8601,
              location_id: location.id,
              published: true
            }
          }
        }.to change(Event, :count).by(1)

        expect(response).to have_http_status(:created)
        event = Event.last
        expect(event.eventable).to be_nil
        expect(event.published).to be true
      end

      it 'can toggle published on update' do
        event = create(:event, eventable: nil, event_type: 'open_house', title: 'Open House')

        patch "/api/events/#{event.id}", params: { event: { published: true } }

        expect(response).to have_http_status(:ok)
        expect(event.reload.published).to be true
      end
    end

    context 'when creating a generic event' do
      it 'creates a new event' do
        expect {
          post '/api/events', params: {
            event: {
              event_type: 'orientation',
              eventable_type: 'EnrollmentApplication',
              eventable_id: application.id,
              location_id: location.id,
              scheduled_at: 1.week.from_now.iso8601,
              title: 'Orientation Day'
            }
          }
        }.to change(Event, :count).by(1)

        expect(response).to have_http_status(:created)
      end

      it 'returns errors for invalid data' do
        post '/api/events', params: {
          event: {
            eventable_type: 'EnrollmentApplication',
            eventable_id: application.id
          }
        }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json).to have_key('errors')
      end
    end
  end

  describe 'PATCH /api/events/:id' do
    let(:event) { create(:event, eventable: application) }

    it 'updates the event' do
      patch "/api/events/#{event.id}", params: {
        event: { notes: 'Updated notes' }
      }

      expect(response).to have_http_status(:success)
      expect(event.reload.notes).to eq('Updated notes')
    end
  end

  describe 'POST /api/events/:id/complete' do
    context 'when completing a meet_and_greet' do
      let(:event) { create(:event, eventable: application, event_type: 'meet_and_greet') }
      let(:service) { instance_double(EnrollmentWorkflowService) }

      before do
        allow(EnrollmentWorkflowService).to receive(:new).with(application).and_return(service)
        allow(service).to receive(:complete_meeting)
      end

      it 'uses the workflow service' do
        post "/api/events/#{event.id}/complete", params: {
          outcome_notes: 'Went well'
        }

        expect(response).to have_http_status(:success)
        expect(service).to have_received(:complete_meeting).with(event.id, outcome_notes: 'Went well')
      end
    end

    context 'when completing a generic event' do
      let(:event) { create(:event, eventable: application, event_type: 'orientation') }

      it 'marks the event as completed' do
        post "/api/events/#{event.id}/complete", params: {
          outcome_notes: 'Successful orientation'
        }

        expect(response).to have_http_status(:success)
        expect(event.reload.status).to eq('completed')
        expect(event.outcome_notes).to eq('Successful orientation')
      end
    end
  end

  describe 'POST /api/events/:id/cancel' do
    let(:event) { create(:event, eventable: application) }

    it 'cancels the event' do
      post "/api/events/#{event.id}/cancel", params: {
        reason: 'Family emergency'
      }

      expect(response).to have_http_status(:success)
      expect(event.reload.status).to eq('cancelled')
    end
  end

  describe 'POST /api/events/:id/confirm' do
    let(:event) { create(:event, eventable: application) }

    it 'confirms the event' do
      post "/api/events/#{event.id}/confirm"

      expect(response).to have_http_status(:success)
      expect(event.reload.status).to eq('confirmed')
    end
  end
end
