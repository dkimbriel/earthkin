require 'rails_helper'

RSpec.describe 'Api::Children', type: :request do
  let(:user) { create(:user) }
  let(:family) { create(:family) }

  before { sign_in user }

  describe 'GET /api/children' do
    before { create_list(:child, 3, family: family) }

    it 'returns all children' do
      get '/api/children'
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json.length).to eq(3)
    end

    it 'filters by family_id' do
      other_family = create(:family)
      create(:child, family: other_family)

      get '/api/children', params: { family_id: family.id }
      json = JSON.parse(response.body)
      expect(json.length).to eq(3)
    end
  end

  describe 'GET /api/children/:id' do
    let(:child) { create(:child, family: family) }

    it 'returns the child' do
      get "/api/children/#{child.id}"
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json['id']).to eq(child.id)
    end
  end

  describe 'POST /api/children' do
    it 'creates a new child' do
      expect {
        post '/api/children', params: {
          child: {
            family_id: family.id,
            first_name: 'Emma',
            last_name: 'Smith'
          }
        }
      }.to change(Child, :count).by(1)

      expect(response).to have_http_status(:created)
    end
  end

  describe 'PATCH /api/children/:id' do
    let(:child) { create(:child, family: family) }

    it 'updates the child' do
      patch "/api/children/#{child.id}", params: {
        child: { first_name: 'Updated Name' }
      }

      expect(response).to have_http_status(:success)
      expect(child.reload.first_name).to eq('Updated Name')
    end
  end

  describe 'DELETE /api/children/:id' do
    let(:child) { create(:child, family: family) }

    it 'deletes the child' do
      child_id = child.id

      expect {
        delete "/api/children/#{child_id}"
      }.to change(Child, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end
end
