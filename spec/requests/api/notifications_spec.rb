require 'rails_helper'

RSpec.describe 'Notifications', type: :request do
  let(:admin) { create(:user) }
  let(:other_admin) { create(:user) }
  let(:teacher) { create(:user, :teacher) }
  let(:parent_user) { create(:user, :parent) }

  let!(:notification_a) do
    Notification.create!(event_type: 'form_signed', title: 'Form signed — Kid A', body: 'Signed.')
  end
  let!(:notification_b) do
    Notification.create!(event_type: 'payment_plan_selected', title: 'Plan selected — Kid B')
  end

  describe 'GET /api/notifications' do
    it 'returns notifications and an unread count for admins' do
      sign_in admin
      get '/api/notifications'

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['notifications'].size).to eq(2)
      # Nothing read yet for this admin, so both are unread.
      expect(body['unread_count']).to eq(2)
    end

    it 'tracks read status independently per user' do
      admin.notification_reads.create!(notification: notification_a, read_at: Time.current)

      sign_in admin
      get '/api/notifications'
      expect(JSON.parse(response.body)['unread_count']).to eq(1)

      sign_in other_admin
      get '/api/notifications'
      # The other admin hasn't read anything, so both remain unread for them.
      expect(JSON.parse(response.body)['unread_count']).to eq(2)
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
    it 'marks a single notification read for the current user only' do
      sign_in admin
      patch "/api/notifications/#{notification_a.id}/mark_read"

      expect(response).to have_http_status(:ok)
      expect(Notification.unread_for(admin)).not_to include(notification_a)
      expect(Notification.unread_for(other_admin)).to include(notification_a)
    end

    it 'is idempotent when marking the same notification read twice' do
      sign_in admin
      patch "/api/notifications/#{notification_a.id}/mark_read"
      patch "/api/notifications/#{notification_a.id}/mark_read"

      expect(response).to have_http_status(:ok)
      expect(admin.notification_reads.where(notification: notification_a).count).to eq(1)
    end

    it 'marks all notifications read for the current user only' do
      sign_in admin
      patch '/api/notifications/mark_all_read'

      expect(response).to have_http_status(:ok)
      expect(Notification.unread_for(admin).count).to eq(0)
      expect(Notification.unread_for(other_admin).count).to eq(2)
    end
  end
end
