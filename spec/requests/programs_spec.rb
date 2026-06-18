require 'rails_helper'

RSpec.describe 'Api::Programs', type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe 'GET /api/programs' do
    before { create_list(:program, 3) }

    it 'returns all programs' do
      get '/api/programs'
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json.length).to eq(3)
    end
  end

  describe 'GET /api/programs/:id' do
    let(:program) { create(:program) }

    it 'returns the program' do
      get "/api/programs/#{program.id}"
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json['id']).to eq(program.id)
    end
  end

  describe 'POST /api/programs' do
    it 'creates a new program' do
      expect {
        post '/api/programs', params: {
          program: {
            name: 'Summer Camp',
            description: 'Outdoor summer program',
            start_date: '2026-06-01',
            end_date: '2026-08-15'
          }
        }
      }.to change(Program, :count).by(1)

      expect(response).to have_http_status(:created)
    end
  end

  describe 'PATCH /api/programs/:id' do
    let(:program) { create(:program) }

    it 'updates the program' do
      patch "/api/programs/#{program.id}", params: {
        program: { name: 'Updated Name' }
      }

      expect(response).to have_http_status(:success)
      expect(program.reload.name).to eq('Updated Name')
    end
  end

  describe 'DELETE /api/programs/:id' do
    let(:program) { create(:program) }

    it 'deletes the program' do
      program_id = program.id

      expect {
        delete "/api/programs/#{program_id}"
      }.to change(Program, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end
end
