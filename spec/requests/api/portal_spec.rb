require 'rails_helper'

RSpec.describe 'Api::Portal', type: :request do
  let(:family) { create(:family) }
  let(:parent_user) { create(:user, :parent) }
  let!(:parent) { create(:parent, family: family, user: parent_user) }
  let!(:child) { create(:child, family: family) }
  let(:program) { create(:program) }
  let!(:enrollment) { create(:program_enrollment, child: child, program: program) }

  describe 'authorization' do
    it 'forbids staff users' do
      sign_in create(:user)

      get '/api/portal/overview'

      expect(response).to have_http_status(:forbidden)
    end

    it 'forbids parent users with no parent record' do
      sign_in create(:user, :parent)

      get '/api/portal/overview'

      expect(response).to have_http_status(:forbidden)
    end

    it 'requires login' do
      get '/api/portal/overview'

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /api/portal/overview' do
    before { sign_in parent_user }

    it 'returns the family, parents and children with enrollments' do
      get '/api/portal/overview'

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['family']['name']).to eq(family.name)
      expect(json['parents'].first['email']).to eq(parent.email)
      expect(json['children'].first['name']).to eq(child.full_name)
      expect(json['children'].first['enrollments'].first['program_name']).to eq(program.name)
    end

    it 'does not include other families' do
      other_family = create(:family)
      create(:child, family: other_family, first_name: 'Other', last_name: 'Kid')

      get '/api/portal/overview'

      json = JSON.parse(response.body)
      expect(json['children'].map { |c| c['name'] }).not_to include('Other Kid')
    end
  end

  describe 'GET /api/portal/events' do
    before { sign_in parent_user }

    it 'returns published school events and enrolled class dates' do
      create(:event, eventable: nil, event_type: 'open_house', title: 'Open House',
                     scheduled_at: 1.week.from_now, published: true)
      create(:event, eventable: nil, event_type: 'other', title: 'Internal Only',
                     scheduled_at: 1.week.from_now, published: false)
      create(:program_class, program: program, name: 'Week 1', date: 2.weeks.from_now.to_date)

      get '/api/portal/events'

      json = JSON.parse(response.body)
      expect(json['events'].map { |e| e['title'] }).to eq(['Open House'])
      expect(json['classes'].first['title']).to include('Week 1')
    end
  end

  describe 'GET /api/portal/payments' do
    before { sign_in parent_user }

    it 'returns enrollment payment info for the family' do
      create(:payment, program_enrollment: enrollment, amount: 100, status: 'completed')

      get '/api/portal/payments'

      json = JSON.parse(response.body)
      expect(json.first['child_name']).to eq(child.full_name)
      expect(json.first['payments'].first['amount']).to eq('100.0')
    end
  end
end
