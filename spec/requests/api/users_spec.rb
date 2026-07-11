require 'rails_helper'

RSpec.describe 'Api::Users', type: :request do
  let(:admin) { create(:user, email: 'admin@example.com') }

  before { sign_in admin }

  describe 'GET /api/users' do
    it 'lists users with roles' do
      create(:user, :parent, email: 'family@example.com')

      get '/api/users'

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.map { |u| u['email'] }).to include('admin@example.com', 'family@example.com')
      expect(json.find { |u| u['email'] == 'family@example.com' }['role']).to eq('parent')
    end

    it 'is forbidden for teachers' do
      sign_in create(:user, :teacher)

      get '/api/users'

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'POST /api/users' do
    it 'creates a teacher user linked to a teacher record' do
      teacher = create(:teacher, email: 'sydney@example.com')

      post '/api/users', params: {
        user: { email: 'sydney@example.com', role: 'teacher', password: 'secret123', teacher_id: teacher.id }
      }

      expect(response).to have_http_status(:created)
      user = User.find_by(email: 'sydney@example.com')
      expect(user.role).to eq('teacher')
      expect(teacher.reload.user).to eq(user)
    end

    it 'generates a password when none is given' do
      post '/api/users', params: { user: { email: 'new@example.com', role: 'admin' } }

      expect(response).to have_http_status(:created)
      expect(User.find_by(email: 'new@example.com')).to be_present
    end

    it 'rejects invalid roles' do
      post '/api/users', params: { user: { email: 'x@example.com', role: 'superuser' } }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'PATCH /api/users/:id' do
    it 'updates the role and password' do
      user = create(:user, :teacher)

      patch "/api/users/#{user.id}", params: { user: { role: 'admin', password: 'newpassword1' } }

      expect(response).to have_http_status(:ok)
      expect(user.reload.role).to eq('admin')
      expect(user.valid_password?('newpassword1')).to be true
    end
  end

  describe 'DELETE /api/users/:id' do
    it 'deletes another user' do
      user = create(:user, :parent)

      expect {
        delete "/api/users/#{user.id}"
      }.to change(User, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it 'refuses to delete yourself' do
      expect {
        delete "/api/users/#{admin.id}"
      }.not_to change(User, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'staff-only API access' do
    it 'forbids parent users from staff endpoints' do
      sign_in create(:user, :parent)

      get '/api/families'

      expect(response).to have_http_status(:forbidden)
    end

    it 'allows teacher users read access to staff endpoints' do
      sign_in create(:user, :teacher)

      get '/api/families'

      expect(response).to have_http_status(:ok)
    end

    it 'blocks teacher users from writing' do
      sign_in create(:user, :teacher)

      post '/api/families', params: { family: { name: 'New Family' } }

      expect(response).to have_http_status(:forbidden)
    end
  end
end
