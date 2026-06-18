require 'rails_helper'

RSpec.describe 'Api::Teachers', type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe 'GET /api/teachers' do
    before { create_list(:teacher, 5) }

    it 'returns all teachers' do
      get '/api/teachers'
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json.length).to eq(5)
    end
  end

  describe 'GET /api/teachers/:id' do
    let(:teacher) { create(:teacher) }

    it 'returns the teacher' do
      get "/api/teachers/#{teacher.id}"
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json['id']).to eq(teacher.id)
    end
  end

  describe 'POST /api/teachers' do
    it 'creates a new teacher' do
      expect {
        post '/api/teachers', params: {
          teacher: {
            first_name: 'Jane',
            last_name: 'Doe',
            email: 'jane@naturepreschool.com'
          }
        }
      }.to change(Teacher, :count).by(1)

      expect(response).to have_http_status(:created)
    end
  end

  describe 'PATCH /api/teachers/:id' do
    let(:teacher) { create(:teacher) }

    it 'updates the teacher' do
      patch "/api/teachers/#{teacher.id}", params: {
        teacher: { first_name: 'Updated' }
      }

      expect(response).to have_http_status(:success)
      expect(teacher.reload.first_name).to eq('Updated')
    end
  end

  describe 'DELETE /api/teachers/:id' do
    let(:teacher) { create(:teacher) }

    it 'deletes the teacher' do
      teacher_id = teacher.id

      expect {
        delete "/api/teachers/#{teacher_id}"
      }.to change(Teacher, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end
end
