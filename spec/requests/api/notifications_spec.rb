require 'rails_helper'

RSpec.describe 'Notifications', type: :request do
  let(:admin) { create(:user) }
  let(:teacher) { create(:user, :teacher) }
  let(:parent_user) { create(:user, :parent) }

  before do
    Notification.create!(event_type: 'form_signed', title: 'Form signed — Kid A', body: 'Signed.')
    Notification.create!(event_type: 'payment_plan_selected', title: 'Plan selected — Kid B', read_at: Time.current)
  end

  describe 'GET /api/notifications' do
    it 'returns notifications and an unread count for admins' do
      sign_in admin
      get '/api/notifications'

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['notifications'].size).to eq(2)
      expect(body['unread_count']).to eq(1)
    end

    it 'forbids teachers' do
      sign_in teacher
      get '/api/notifications'
      expect(response).to have_http_status(:forbidden)
    end

    it 'forbids parents' do
      sign_in parent_user
      get '/api/notifications'
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'PATCH mark_read / mark_all_read' do
    it 'marks a single notification read' do
      sign_in admin
      notification = Notification.unread.first
      patch "/api/notifications/#{notification.id}/mark_read"

      expect(response).to have_http_status(:ok)
      expect(notification.reload.read?).to be(true)
    end

    it 'marks all notifications read' do
      sign_in admin
      patch '/api/notifications/mark_all_read'

      expect(response).to have_http_status(:ok)
      expect(Notification.unread.count).to eq(0)
    end
  end
end
