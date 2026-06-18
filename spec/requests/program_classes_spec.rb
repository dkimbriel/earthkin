require 'rails_helper'

RSpec.describe 'Api::ProgramClasses', type: :request do
  let(:user) { create(:user) }
  let(:program) { create(:program) }
  let(:teacher) { create(:teacher) }

  before { sign_in user }

  describe 'GET /api/program_classes' do
    before { create_list(:program_class, 3, program: program) }

    it 'returns all program classes' do
      get '/api/program_classes'
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json.length).to eq(3)
    end

    it 'filters by program_id' do
      other_program = create(:program)
      create(:program_class, program: other_program)

      get '/api/program_classes', params: { program_id: program.id }
      json = JSON.parse(response.body)
      expect(json.length).to eq(3)
    end
  end

  describe 'GET /api/program_classes/:id' do
    let(:program_class) { create(:program_class, program: program) }

    it 'returns the program class' do
      get "/api/program_classes/#{program_class.id}"
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json['id']).to eq(program_class.id)
    end
  end

  describe 'POST /api/program_classes' do
    it 'creates a new program class' do
      expect {
        post '/api/program_classes', params: {
          program_class: {
            program_id: program.id,
            name: 'Morning Forest Explorers',
            date: Date.today
          }
        }
      }.to change(ProgramClass, :count).by(1)

      expect(response).to have_http_status(:created)
    end
  end

  describe 'PATCH /api/program_classes/:id' do
    let(:program_class) { create(:program_class, program: program) }

    it 'updates the program class' do
      patch "/api/program_classes/#{program_class.id}", params: {
        program_class: { name: 'Updated Class Name' }
      }

      expect(response).to have_http_status(:success)
      expect(program_class.reload.name).to eq('Updated Class Name')
    end
  end

  describe 'DELETE /api/program_classes/:id' do
    let(:program_class) { create(:program_class, program: program) }

    it 'deletes the program class' do
      program_class_id = program_class.id

      expect {
        delete "/api/program_classes/#{program_class_id}"
      }.to change(ProgramClass, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end
end
