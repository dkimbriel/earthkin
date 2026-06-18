require 'rails_helper'

RSpec.describe 'Api::Locations', type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe 'GET /api/locations' do
    before { create_list(:location, 4) }

    it 'returns all locations' do
      get '/api/locations'
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json.length).to eq(4)
    end
  end

  describe 'GET /api/locations/:id' do
    let(:location) { create(:location) }

    it 'returns the location' do
      get "/api/locations/#{location.id}"
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json['id']).to eq(location.id)
    end
  end

  describe 'POST /api/locations' do
    it 'creates a new location' do
      expect {
        post '/api/locations', params: {
          location: {
            name: 'Forest Hill Park',
            address: '4021 Forest Hill Avenue'
          }
        }
      }.to change(Location, :count).by(1)

      expect(response).to have_http_status(:created)
    end
  end

  describe 'PATCH /api/locations/:id' do
    let(:location) { create(:location) }

    it 'updates the location' do
      patch "/api/locations/#{location.id}", params: {
        location: { name: 'Updated Park Name' }
      }

      expect(response).to have_http_status(:success)
      expect(location.reload.name).to eq('Updated Park Name')
    end
  end

  describe 'DELETE /api/locations/:id' do
    let(:location) { create(:location) }

    it 'deletes the location' do
      location_id = location.id

      expect {
        delete "/api/locations/#{location_id}"
      }.to change(Location, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end
end
