require 'rails_helper'

RSpec.describe 'Api::Families', type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe 'GET /api/families' do
    before { create_list(:family, 5) }

    it 'returns all families' do
      get '/api/families'
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json.length).to eq(5)
    end
  end

  describe 'GET /api/families/:id' do
    let(:family) { create(:family) }
    let!(:parent) { create(:parent, family: family) }
    let!(:child) { create(:child, family: family) }

    it 'returns the family with associations' do
      get "/api/families/#{family.id}"
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json['id']).to eq(family.id)
      expect(json).to have_key('parents')
      expect(json).to have_key('children')
    end
  end

  describe 'POST /api/families' do
    it 'creates a new family' do
      expect {
        post '/api/families', params: {
          family: {
            name: 'Johnson Family'
          }
        }
      }.to change(Family, :count).by(1)

      expect(response).to have_http_status(:created)
    end
  end

  describe 'PATCH /api/families/:id' do
    let(:family) { create(:family) }

    it 'updates the family' do
      patch "/api/families/#{family.id}", params: {
        family: { name: 'Updated Family Name' }
      }

      expect(response).to have_http_status(:success)
      expect(family.reload.name).to eq('Updated Family Name')
    end
  end

  describe 'DELETE /api/families/:id' do
    let(:family) { create(:family) }

    it 'deletes the family' do
      family_id = family.id

      expect {
        delete "/api/families/#{family_id}"
      }.to change(Family, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end
end
