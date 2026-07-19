require 'rails_helper'

RSpec.describe 'Admin deleted records', type: :request do
  let(:admin) { create(:user) }
  let(:teacher) { create(:user, :teacher) }
  let!(:family) { create(:family) }
  let!(:child) { create(:child, family: family) }

  describe 'GET /api/admin/deleted_records' do
    it 'lists root deletions but not their cascade children' do
      family.soft_delete!
      sign_in admin

      get '/api/admin/deleted_records'
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)

      types = body.map { |r| r['type'] }
      expect(types).to include('Family')
      expect(types).not_to include('Child') # cascade child is hidden
      expect(body.find { |r| r['type'] == 'Family' }['label']).to eq(family.full_name)
    end

    it 'forbids non-admins' do
      sign_in teacher
      get '/api/admin/deleted_records'
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'POST /api/admin/deleted_records/restore' do
    it 'restores the record and its cascade children' do
      family.soft_delete!
      sign_in admin

      post '/api/admin/deleted_records/restore', params: { type: 'Family', id: family.id }

      expect(response).to have_http_status(:ok)
      expect(Family.exists?(family.id)).to be(true)
      expect(Child.exists?(child.id)).to be(true)
    end

    it 'rejects an unknown type' do
      sign_in admin
      post '/api/admin/deleted_records/restore', params: { type: 'Nope', id: family.id }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
