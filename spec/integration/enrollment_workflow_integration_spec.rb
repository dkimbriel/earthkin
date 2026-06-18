require 'rails_helper'

RSpec.describe 'Enrollment Workflow Integration', type: :request do
  let(:user) { create(:user) }
  let(:program) { create(:program, name: 'Forest Explorers', start_date: '2026-09-01', end_date: '2027-05-31') }
  let(:location) { create(:location, name: 'Forest Hill Park') }
  let!(:payment_plans) do
    [
      create(:payment_plan, program: program, name: 'Full Payment', installment_count: 1, total_amount: 2800),
      create(:payment_plan, :monthly, program: program, name: 'Monthly', installment_count: 10, total_amount: 2800)
    ]
  end

  before do
    allow(EnrollmentEmailJob).to receive(:perform_async)
    allow(PaymentMailer).to receive_message_chain(:invoice, :deliver_later)
    allow(PaymentMailer).to receive_message_chain(:receipt, :deliver_later)
  end

  describe 'Complete enrollment workflow' do
    it 'processes a complete enrollment from application to enrollment' do
      # Step 1: Public enrollment application submission
      application_params = {
        enrollment_application: {
          program_id: program.id,
          parent_first_name: 'Sarah',
          parent_last_name: 'Johnson',
          parent_email: 'sarah@example.com',
          parent_phone: '(555) 123-4567',
          child_first_name: 'Emma',
          child_last_name: 'Johnson',
          child_date_of_birth: '2022-03-15',
          why_interested: 'Nature-based education',
          child_description: 'Loves outdoor activities'
        }
      }

      post '/api/enrollment_applications', params: application_params
      expect(response).to have_http_status(:created)
      application_data = JSON.parse(response.body)
      application_id = application_data['id']

      # Step 2: Admin reviews application
      sign_in user

      get "/api/enrollment_applications/#{application_id}"
      expect(response).to have_http_status(:success)

      post "/api/enrollment_applications/#{application_id}/mark_reviewed"
      expect(response).to have_http_status(:success)

      # Step 3: Admin schedules meeting
      meeting_params = {
        event: {
          event_type: 'meet_and_greet',
          eventable_type: 'EnrollmentApplication',
          eventable_id: application_id,
          location_id: location.id,
          scheduled_at: 1.week.from_now.iso8601,
          notes: 'Looking forward to meeting'
        }
      }

      post '/api/events', params: meeting_params
      expect(response).to have_http_status(:created)
      event_data = JSON.parse(response.body)
      event_id = event_data['id']

      # Step 4: Complete meeting
      post "/api/events/#{event_id}/confirm"
      expect(response).to have_http_status(:success)

      # Step 5: Process enrollment fee payment
      fee_payment_params = {
        payment_plan_id: payment_plans.first.id,
        payment_method: 'venmo',
        payment_date: Date.today.to_s,
        notes: 'Venmo payment received'
      }

      post "/api/enrollment_applications/#{application_id}/process_fee_payment",
           params: fee_payment_params
      expect(response).to have_http_status(:success)

      result = JSON.parse(response.body)
      expect(result).to have_key('enrollment')
      expect(result).to have_key('payment')

      enrollment = result['enrollment']
      expect(enrollment).to be_present

      # Verify family and child were created
      application = EnrollmentApplication.find(application_id)
      expect(application.family).to be_present
      expect(application.child).to be_present
      expect(application.status).to eq('fee_paid')

      # Step 6: View and manage payment plans
      get '/api/payment_plans', params: { program_id: program.id }
      expect(response).to have_http_status(:success)
      plans = JSON.parse(response.body)
      expect(plans.length).to be >= 2

      # Step 7: View program enrollments
      get '/api/program_enrollments'
      expect(response).to have_http_status(:success)

      # Step 8: Record additional payment
      enrollment_id = enrollment['id']
      tuition_payment_params = {
        payment: {
          program_enrollment_id: enrollment_id,
          amount: 280.00,
          payment_date: Date.today.to_s,
          payment_method: 'venmo',
          status: 'completed',
          notes: 'First tuition payment'
        }
      }

      post '/api/payments', params: tuition_payment_params
      expect(response).to have_http_status(:created)

      # Step 9: View payments
      get '/api/payments', params: { program_enrollment_id: enrollment_id }
      expect(response).to have_http_status(:success)
      payments = JSON.parse(response.body)
      expect(payments.length).to be >= 2 # Enrollment fee + tuition payment
    end
  end

  describe 'Multiple applications scenario' do
    it 'handles multiple applications and filtering' do
      sign_in user

      # Create multiple applications with different statuses
      app1 = create(:enrollment_application, program: program, status: 'submitted')
      app2 = create(:enrollment_application, :reviewed, program: program)
      app3 = create(:enrollment_application, :enrolled, program: program)

      # Test filtering by status
      get '/api/enrollment_applications', params: { status: 'reviewed' }
      expect(response).to have_http_status(:success)
      apps = JSON.parse(response.body)
      expect(apps.any? { |a| a['id'] == app2.id }).to be true

      # Test filtering by program
      other_program = create(:program)
      create(:enrollment_application, program: other_program)

      get '/api/enrollment_applications', params: { program_id: program.id }
      expect(response).to have_http_status(:success)
      apps = JSON.parse(response.body)
      expect(apps.all? { |a| a['program']['id'] == program.id }).to be true
    end
  end

  describe 'Events and locations' do
    it 'manages events for enrollment applications' do
      sign_in user

      application = create(:enrollment_application, program: program)

      # Create orientation event
      event_params = {
        event: {
          event_type: 'orientation',
          eventable_type: 'EnrollmentApplication',
          eventable_id: application.id,
          location_id: location.id,
          scheduled_at: 2.weeks.from_now.iso8601,
          title: 'New Family Orientation'
        }
      }

      post '/api/events', params: event_params
      expect(response).to have_http_status(:created)

      # List all events
      get '/api/events'
      expect(response).to have_http_status(:success)

      # Filter by event type
      get '/api/events', params: { event_type: 'orientation' }
      expect(response).to have_http_status(:success)
    end
  end

  describe 'Error handling' do
    it 'handles invalid enrollment application data' do
      invalid_params = {
        enrollment_application: {
          program_id: program.id
          # Missing required fields
        }
      }

      post '/api/enrollment_applications', params: invalid_params
      expect(response).to have_http_status(:bad_request)
    end

    it 'requires authentication for admin endpoints' do
      application = create(:enrollment_application, program: program)

      get '/api/enrollment_applications'
      expect(response).to have_http_status(:unauthorized)

      get "/api/enrollment_applications/#{application.id}"
      expect(response).to have_http_status(:unauthorized)

      post "/api/enrollment_applications/#{application.id}/mark_reviewed"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
