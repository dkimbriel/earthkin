require 'rails_helper'

RSpec.describe 'Api::ContentItems', type: :request do
  let(:admin) { create(:user) }

  describe 'admin management' do
    before { sign_in admin }

    it 'creates, updates and deletes content items' do
      post '/api/content_items', params: {
        content_item: { title: 'Staff Manual', url: 'https://drive.google.com/abc', category: 'manual' }
      }
      expect(response).to have_http_status(:created)
      item = ContentItem.last
      expect(item.visibility).to eq('all_staff')

      patch "/api/content_items/#{item.id}", params: { content_item: { title: 'Staff Manual v2' } }
      expect(response).to have_http_status(:ok)
      expect(item.reload.title).to eq('Staff Manual v2')

      delete "/api/content_items/#{item.id}"
      expect(response).to have_http_status(:no_content)
      expect(ContentItem.exists?(item.id)).to be false
    end

    it 'rejects non-links' do
      post '/api/content_items', params: { content_item: { title: 'Bad', url: 'not-a-url' } }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'assigns specific teachers' do
      teacher = create(:teacher)

      post '/api/content_items', params: {
        content_item: {
          title: 'Toddler Curriculum',
          url: 'https://drive.google.com/xyz',
          visibility: 'specific_teachers',
          teacher_ids: [teacher.id]
        }
      }

      expect(response).to have_http_status(:created)
      expect(ContentItem.last.teachers).to eq([teacher])
    end
  end

  describe 'family visibility' do
    let(:parent_user) { create(:user, :parent) }
    let!(:parent) { create(:parent, family: create(:family), user: parent_user) }

    before do
      create(:content_item, title: 'Family Handbook', visible_to_families: true)
      create(:content_item, title: 'Gear & Attire List', visible_to_families: true)
      create(:content_item, title: 'Staff Only Manual', visible_to_families: false)
    end

    it 'admins can flag an item visible to families' do
      sign_in admin
      post '/api/content_items', params: {
        content_item: { title: 'New Doc', url: 'https://drive.google.com/x', visible_to_families: true }
      }
      expect(response).to have_http_status(:created)
      expect(ContentItem.find_by(title: 'New Doc').visible_to_families).to be true
    end

    it 'families see only family-visible items in the portal' do
      sign_in parent_user
      get '/api/portal/content'

      expect(response).to have_http_status(:ok)
      titles = JSON.parse(response.body).map { |i| i['title'] }
      expect(titles).to contain_exactly('Family Handbook', 'Gear & Attire List')
      expect(titles).not_to include('Staff Only Manual')
    end

    it 'the family documents endpoint is parents-only' do
      sign_in admin
      get '/api/portal/content'
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'teacher visibility' do
    let(:teacher_record) { create(:teacher) }
    let(:teacher_user) { create(:user, :teacher) }

    before do
      teacher_record.update!(user: teacher_user)

      create(:content_item, title: 'Everyone Manual')
      create(:content_item, :specific, title: 'Mine Only', teachers: [teacher_record])
      create(:content_item, :specific, title: 'Someone Else', teachers: [create(:teacher)])
    end

    it 'teachers see all_staff items plus their own assignments' do
      sign_in teacher_user

      get '/api/content_items'

      titles = JSON.parse(response.body).map { |i| i['title'] }
      expect(titles).to contain_exactly('Everyone Manual', 'Mine Only')
    end

    it 'admins see everything' do
      sign_in admin

      get '/api/content_items'

      titles = JSON.parse(response.body).map { |i| i['title'] }
      expect(titles).to contain_exactly('Everyone Manual', 'Mine Only', 'Someone Else')
    end

    it 'teachers cannot create content' do
      sign_in teacher_user

      post '/api/content_items', params: { content_item: { title: 'X', url: 'https://x.com' } }

      expect(response).to have_http_status(:forbidden)
    end
  end
end
