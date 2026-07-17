require 'rails_helper'

RSpec.describe 'Api::Parents', type: :request do
  let(:user) { create(:user) }
  let(:family) { create(:family) }

  before { sign_in user }

  describe 'GET /api/parents' do
    before { create_list(:parent, 3, family: family) }

    it 'returns all parents' do
      get '/api/parents'
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json.length).to eq(3)
    end

    it 'filters by family_id' do
      other_family = create(:family)
      create(:parent, family: other_family)

      get '/api/parents', params: { family_id: family.id }
      json = JSON.parse(response.body)
      expect(json.length).to eq(3)
    end
  end

  describe 'GET /api/parents/:id' do
    let(:parent) { create(:parent, family: family) }

    it 'returns the parent' do
      get "/api/parents/#{parent.id}"
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json['id']).to eq(parent.id)
    end
  end

  describe 'POST /api/parents' do
    it 'creates a new parent' do
      expect {
        post '/api/parents', params: {
          parent: {
            family_id: family.id,
            first_name: 'John',
            last_name: 'Doe',
            email: 'john.doe@example.com',
            phone: '(555) 123-4567'
          }
        }
      }.to change(Parent, :count).by(1)

      expect(response).to have_http_status(:created)
    end
  end

  describe 'PATCH /api/parents/:id' do
    let(:parent) { create(:parent, family: family) }

    it 'updates the parent' do
      patch "/api/parents/#{parent.id}", params: {
        parent: { first_name: 'Updated' }
      }

      expect(response).to have_http_status(:success)
      expect(parent.reload.first_name).to eq('Updated')
    end
  end

  describe 'DELETE /api/parents/:id' do
    let(:parent) { create(:parent, family: family) }

    it 'deletes the parent' do
      parent_id = parent.id

      expect {
        delete "/api/parents/#{parent_id}"
      }.to change(Parent, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end

  describe 'POST /api/parents/:id/invite' do
    let(:family) { create(:family) }

    it 'creates a portal login and sends the welcome email' do
      parent = create(:parent, family: family, email: 'newlogin@example.com', user: nil)

      expect {
        post "/api/parents/#{parent.id}/invite"
      }.to change(User, :count).by(1)
       .and change { ActionMailer::Base.deliveries.count }.by(1)

      expect(response).to have_http_status(:ok)
      parent.reload
      expect(parent.user).to be_present
      expect(parent.user.role).to eq('parent')
      expect(parent.emails.by_type('welcome_email').last.status).to eq('sent')
    end

    it 'refuses when the parent already has a login' do
      parent = create(:parent, family: family, user: create(:user, :parent))

      expect {
        post "/api/parents/#{parent.id}/invite"
      }.not_to change(User, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('already has a portal login')
    end
  end
end
