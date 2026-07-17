require 'rails_helper'

RSpec.describe 'Api::EnrollmentApplications', type: :request do
  let(:user) { create(:user) }
  let(:program) { create(:program) }

  describe 'GET /api/enrollment_applications' do
    before do
      create_list(:enrollment_application, 3, program: program)
    end

    context 'when authenticated' do
      before { sign_in user }

      it 'returns all enrollment applications' do
        get '/api/enrollment_applications'
        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json.length).to eq(3)
      end

      it 'filters by status' do
        reviewed_app = create(:enrollment_application, :reviewed, program: program)
        get '/api/enrollment_applications', params: { status: 'reviewed' }
        json = JSON.parse(response.body)
        expect(json.length).to eq(1)
        expect(json.first['id']).to eq(reviewed_app.id)
      end

      it 'filters by program_id' do
        other_program = create(:program)
        create(:enrollment_application, program: other_program)

        get '/api/enrollment_applications', params: { program_id: program.id }
        json = JSON.parse(response.body)
        expect(json.length).to eq(3)
      end

      it 'includes associated records' do
        get '/api/enrollment_applications'
        json = JSON.parse(response.body)
        expect(json.first).to have_key('program')
        expect(json.first).to have_key('full_child_name')
        expect(json.first).to have_key('full_parent_name')
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        get '/api/enrollment_applications'
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/enrollment_applications/:id' do
    let(:application) { create(:enrollment_application, program: program) }

    context 'when authenticated' do
      before { sign_in user }

      it 'returns the enrollment application' do
        get "/api/enrollment_applications/#{application.id}"
        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json['id']).to eq(application.id)
      end

      it 'includes nested associations' do
        get "/api/enrollment_applications/#{application.id}"
        json = JSON.parse(response.body)
        expect(json).to have_key('program')
        expect(json).to have_key('events')
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        get "/api/enrollment_applications/#{application.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/enrollment_applications' do
    let(:valid_params) do
      {
        enrollment_application: {
          program_id: program.id,
          parent_first_name: 'Jane',
          parent_last_name: 'Doe',
          parent_email: 'jane@example.com',
          parent_phone: '(555) 123-4567',
          child_first_name: 'Johnny',
          child_last_name: 'Doe',
          child_date_of_birth: '2020-05-15',
          why_interested: 'Great program',
          child_description: 'Active and curious',
          is_local: 'yes',
          referral_source: 'Instagram'
        }
      }
    end

    it 'creates a new enrollment application without authentication' do
      expect {
        post '/api/enrollment_applications', params: valid_params
      }.to change(EnrollmentApplication, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['status']).to eq('submitted')
      expect(json['submitted_at']).to be_present
    end

    it 'does not send any automatic email on submission' do
      expect {
        post '/api/enrollment_applications', params: valid_params
      }.not_to change { ActionMailer::Base.deliveries.count }
    end

    it 'returns errors for invalid data' do
      post '/api/enrollment_applications', params: {
        enrollment_application: { program_id: program.id }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json).to have_key('errors')
    end
  end

  describe 'PATCH /api/enrollment_applications/:id' do
    let(:application) { create(:enrollment_application, program: program) }

    before { sign_in user }

    it 'updates the enrollment application' do
      patch "/api/enrollment_applications/#{application.id}", params: {
        enrollment_application: { admin_notes: 'Updated notes' }
      }

      expect(response).to have_http_status(:success)
      expect(application.reload.admin_notes).to eq('Updated notes')
    end
  end

  describe 'POST /api/enrollment_applications/:id/mark_reviewed' do
    let(:application) { create(:enrollment_application, program: program) }
    let(:service) { instance_double(EnrollmentWorkflowService) }

    before do
      sign_in user
      allow(EnrollmentWorkflowService).to receive(:new).with(application).and_return(service)
      allow(service).to receive(:process_inquiry)
    end

    it 'marks application as reviewed' do
      post "/api/enrollment_applications/#{application.id}/mark_reviewed"

      expect(response).to have_http_status(:success)
      expect(service).to have_received(:process_inquiry)
    end
  end

  describe 'POST /api/enrollment_applications/:id/decline' do
    let(:application) { create(:enrollment_application, program: program) }

    before { sign_in user }

    it 'declines the application' do
      post "/api/enrollment_applications/#{application.id}/decline", params: {
        notes: 'Not a good fit'
      }

      expect(response).to have_http_status(:success)
      expect(application.reload.status).to eq('declined')
      expect(application.admin_notes).to eq('Not a good fit')
    end
  end

  describe 'POST /api/enrollment_applications/:id/request_fee' do
    let(:application) { create(:enrollment_application, :reviewed, program: program) }
    let(:service) { instance_double(EnrollmentWorkflowService) }

    before do
      sign_in user
      allow(EnrollmentWorkflowService).to receive(:new).with(application).and_return(service)
      allow(service).to receive(:request_enrollment_fee)
    end

    it 'requests enrollment fee' do
      post "/api/enrollment_applications/#{application.id}/request_fee"

      expect(response).to have_http_status(:success)
      expect(service).to have_received(:request_enrollment_fee)
    end
  end

  describe 'POST /api/enrollment_applications/:id/process_fee_payment' do
    let(:application) { create(:enrollment_application, program: program, status: 'meeting_completed') }
    let(:payment_plan) { create(:payment_plan, program: program) }
    let(:service) { instance_double(EnrollmentWorkflowService) }
    let(:enrollment) { create(:program_enrollment, program: program, enrollment_application: application) }
    let(:payment) { create(:payment, :enrollment_fee, program_enrollment: enrollment) }

    before do
      sign_in user
      allow(EnrollmentWorkflowService).to receive(:new).with(application).and_return(service)
      allow(service).to receive(:process_enrollment_fee_payment).and_return({
        enrollment: enrollment,
        payment: payment
      })
    end

    it 'processes fee payment and creates enrollment' do
      post "/api/enrollment_applications/#{application.id}/process_fee_payment", params: {
        payment_plan_id: payment_plan.id,
        payment_method: 'venmo',
        payment_date: Date.today.to_s,
        notes: 'Paid via Venmo'
      }

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json).to have_key('application')
      expect(json).to have_key('enrollment')
      expect(json).to have_key('payment')
    end
  end
end
