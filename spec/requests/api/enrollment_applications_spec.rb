require 'rails_helper'

RSpec.describe 'Api::EnrollmentApplications', type: :request do
  let(:program) { create(:program) }
  let(:user) { create(:user) }

  before do
    sign_in user
  end

  describe 'GET /api/enrollment_applications' do
    let!(:applications) { create_list(:enrollment_application, 3, program: program) }

    it 'returns all applications' do
      get '/api/enrollment_applications'
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).length).to eq(3)
    end

    it 'filters by program_id' do
      other_program = create(:program)
      create(:enrollment_application, program: other_program)

      get '/api/enrollment_applications', params: { program_id: program.id }
      expect(JSON.parse(response.body).length).to eq(3)
    end

    it 'filters by status' do
      create(:enrollment_application, :reviewed, program: program)

      get '/api/enrollment_applications', params: { status: 'reviewed' }
      expect(JSON.parse(response.body).length).to eq(1)
    end
  end

  describe 'GET /api/enrollment_applications/:id' do
    let(:application) { create(:enrollment_application) }

    it 'returns the application' do
      get "/api/enrollment_applications/#{application.id}"
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['id']).to eq(application.id)
      expect(json['parent_email']).to eq(application.parent_email)
    end
  end

  describe 'POST /api/enrollment_applications' do
    let(:valid_params) do
      {
        enrollment_application: {
          program_id: program.id,
          parent_first_name: 'John',
          parent_last_name: 'Doe',
          # Parent 2 fields are optional
          parent_email: 'john@example.com',
          parent_phone: '(555) 123-4567',
          child_first_name: 'Lily',
          child_last_name: 'Doe',
          child_date_of_birth: '2020-01-01',
          child_description: 'A curious and energetic child who loves being outdoors.',
          why_interested: 'Great program!',
          is_local: 'yes',
          referral_source: 'Instagram'
        }
      }
    end

    it 'creates a new application without authentication' do
      sign_out user

      expect {
        post '/api/enrollment_applications', params: valid_params
      }.to change(EnrollmentApplication, :count).by(1)

      expect(response).to have_http_status(:created)
    end

    it 'records an admin notification on submission' do
      sign_out user

      expect {
        post '/api/enrollment_applications', params: valid_params
      }.to change(Notification, :count).by(1)

      expect(Notification.last.event_type).to eq('application_submitted')
    end

    it 'does not email the applicant on submission' do
      # The submission alert goes to the school's own connected mailbox, not to
      # the family. With no mailbox connected in the test env, nothing delivers.
      expect {
        post '/api/enrollment_applications', params: valid_params
      }.not_to change { ActionMailer::Base.deliveries.count }
    end

    it 'returns error with invalid params' do
      post '/api/enrollment_applications', params: { enrollment_application: { program_id: program.id } }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'POST /api/enrollment_applications/:id/mark_reviewed' do
    let(:application) { create(:enrollment_application) }

    it 'marks application as reviewed' do
      post "/api/enrollment_applications/#{application.id}/mark_reviewed"

      expect(response).to have_http_status(:ok)
      expect(application.reload.status).to eq('reviewed')
    end
  end

  describe 'POST /api/enrollment_applications/:id/decline' do
    let(:application) { create(:enrollment_application) }

    it 'declines the application' do
      post "/api/enrollment_applications/#{application.id}/decline",
        params: { admin_notes: 'Not a good fit' }

      expect(response).to have_http_status(:ok)
      expect(application.reload.status).to eq('declined')
      expect(application.declined_at).to be_present
    end
  end

  describe 'POST /api/enrollment_applications/:id/reopen' do
    it 'reopens a declined application back to submitted' do
      application = create(:enrollment_application, :declined)

      post "/api/enrollment_applications/#{application.id}/reopen"

      expect(response).to have_http_status(:ok)
      expect(application.reload.status).to eq('submitted')
      expect(application.declined_at).to be_nil
    end

    it 'rejects reopening an application that is not declined' do
      application = create(:enrollment_application, :reviewed)

      post "/api/enrollment_applications/#{application.id}/reopen"

      expect(response).to have_http_status(:unprocessable_entity)
      expect(application.reload.status).to eq('reviewed')
    end
  end

  describe 'POST /api/enrollment_applications/:id/process_fee_payment' do
    let(:application) { create(:enrollment_application, :meeting_completed) }
    let(:payment_plan) { create(:payment_plan, program: application.program) }

    it 'processes enrollment fee payment' do
      expect {
        post "/api/enrollment_applications/#{application.id}/process_fee_payment",
          params: {
            payment_plan_id: payment_plan.id,
            payment_method: 'venmo',
            payment_date: Date.today
          }
      }.to change(Payment, :count).by(1)
        .and change(ProgramEnrollment, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(application.reload.status).to eq('fee_paid')
    end
  end
end
