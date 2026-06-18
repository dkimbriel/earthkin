require 'rails_helper'

RSpec.describe 'Api::ProgramEnrollments', type: :request do
  let(:user) { create(:user) }
  let(:program) { create(:program) }
  let(:family) { create(:family) }
  let(:child) { create(:child, family: family) }

  before { sign_in user }

  describe 'GET /api/program_enrollments' do
    before do
      create_list(:program_enrollment, 3, program: program)
    end

    it 'returns all enrollments' do
      get '/api/program_enrollments'
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json.length).to eq(3)
    end

    it 'filters by program_id' do
      other_program = create(:program)
      create(:program_enrollment, program: other_program)

      get '/api/program_enrollments', params: { program_id: program.id }
      json = JSON.parse(response.body)
      expect(json.length).to eq(3)
    end

    it 'filters by child_id' do
      specific_child = create(:child, family: family)
      enrollment = create(:program_enrollment, child: specific_child, program: program)

      get '/api/program_enrollments', params: { child_id: specific_child.id }
      json = JSON.parse(response.body)
      expect(json.first['id']).to eq(enrollment.id)
    end

    it 'filters by status' do
      create(:program_enrollment, :cancelled, program: program)

      get '/api/program_enrollments', params: { status: 'cancelled' }
      json = JSON.parse(response.body)
      expect(json.all? { |e| e['status'] == 'cancelled' }).to be true
    end
  end

  describe 'GET /api/program_enrollments/:id' do
    let(:enrollment) { create(:program_enrollment, program: program) }

    it 'returns the enrollment with associations' do
      get "/api/program_enrollments/#{enrollment.id}"
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json['id']).to eq(enrollment.id)
      expect(json).to have_key('program')
      expect(json).to have_key('child')
    end
  end

  describe 'POST /api/program_enrollments' do
    it 'creates a new enrollment' do
      expect {
        post '/api/program_enrollments', params: {
          program_enrollment: {
            program_id: program.id,
            child_id: child.id,
            status: 'active',
            rate_per_class: 50.0
          }
        }
      }.to change(ProgramEnrollment, :count).by(1)

      expect(response).to have_http_status(:created)
    end
  end

  describe 'PATCH /api/program_enrollments/:id' do
    let(:enrollment) { create(:program_enrollment, program: program) }

    it 'updates the enrollment' do
      patch "/api/program_enrollments/#{enrollment.id}", params: {
        program_enrollment: { status: 'withdrawn' }
      }

      expect(response).to have_http_status(:success)
      expect(enrollment.reload.status).to eq('withdrawn')
    end
  end

  describe 'DELETE /api/program_enrollments/:id' do
    let(:enrollment) { create(:program_enrollment, program: program) }

    it 'deletes the enrollment' do
      enrollment_id = enrollment.id

      expect {
        delete "/api/program_enrollments/#{enrollment_id}"
      }.to change(ProgramEnrollment, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end
end
