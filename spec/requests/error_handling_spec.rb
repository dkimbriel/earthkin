require 'rails_helper'

RSpec.describe 'Error Handling', type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe 'Record not found errors' do
    it 'returns 404 for non-existent program' do
      get '/api/programs/00000000-0000-0000-0000-000000000000'
      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json['error']).to eq('Record not found')
    end

    it 'returns 404 for non-existent enrollment' do
      get '/api/program_enrollments/00000000-0000-0000-0000-000000000000'
      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 for non-existent payment' do
      get '/api/payments/00000000-0000-0000-0000-000000000000'
      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 for non-existent family' do
      get '/api/families/00000000-0000-0000-0000-000000000000'
      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 for non-existent child' do
      get '/api/children/00000000-0000-0000-0000-000000000000'
      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 for non-existent parent' do
      get '/api/parents/00000000-0000-0000-0000-000000000000'
      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 for non-existent location' do
      get '/api/locations/00000000-0000-0000-0000-000000000000'
      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 for non-existent teacher' do
      get '/api/teachers/00000000-0000-0000-0000-000000000000'
      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 for non-existent payment plan' do
      get '/api/payment_plans/00000000-0000-0000-0000-000000000000'
      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 for non-existent enrollment application' do
      get '/api/enrollment_applications/00000000-0000-0000-0000-000000000000'
      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 for non-existent event' do
      get '/api/events/00000000-0000-0000-0000-000000000000'
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'Validation errors' do
    it 'returns 422 for invalid program creation' do
      post '/api/programs', params: {
        program: { name: '' } # Missing required fields
      }
      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json['errors']).to be_present
    end

    it 'returns 422 for invalid family creation' do
      post '/api/families', params: {
        family: { name: '' }
      }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'returns 422 for invalid child creation without family' do
      post '/api/children', params: {
        child: {
          first_name: 'Test',
          last_name: 'Child'
        }
      }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'returns 422 for invalid parent with bad email' do
      family = create(:family)
      post '/api/parents', params: {
        parent: {
          family_id: family.id,
          first_name: 'Test',
          last_name: 'Parent',
          email: '' # Empty email
        }
      }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'returns 422 for invalid payment amount' do
      enrollment = create(:program_enrollment)
      post '/api/payments', params: {
        payment: {
          program_enrollment_id: enrollment.id,
          amount: -100, # Negative amount
          payment_date: Date.today,
          payment_method: 'venmo',
          status: 'completed'
        }
      }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'returns 422 for invalid location without name' do
      post '/api/locations', params: {
        location: { address: '123 Main St' }
      }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'returns 422 for invalid teacher without email' do
      post '/api/teachers', params: {
        teacher: {
          first_name: 'Jane',
          last_name: 'Doe'
        }
      }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'returns 422 for invalid program class without required fields' do
      post '/api/program_classes', params: {
        program_class: { name: 'Test Class' }
      }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'returns 422 for invalid enrollment without required fields' do
      post '/api/program_enrollments', params: {
        program_enrollment: { status: 'active' }
      }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'Update errors' do
    let(:program) { create(:program) }

    it 'returns 422 when updating with invalid data' do
      patch "/api/programs/#{program.id}", params: {
        program: { name: '' }
      }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'returns 404 when updating non-existent record' do
      patch '/api/programs/00000000-0000-0000-0000-000000000000', params: {
        program: { name: 'Updated' }
      }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'Delete errors' do
    it 'returns 404 when deleting non-existent record' do
      delete '/api/programs/00000000-0000-0000-0000-000000000000'
      expect(response).to have_http_status(:not_found)
    end
  end
end
