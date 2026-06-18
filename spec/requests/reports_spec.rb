require 'rails_helper'

RSpec.describe 'Api::Reports', type: :request do
  let(:user) { create(:user) }
  let(:program) { create(:program) }

  before { sign_in user }

  describe 'GET /api/reports/weekly_revenue' do
    before do
      # Create program classes for different weeks
      create(:program_class, program: program, date: 1.week.ago.to_date)
      create(:program_class, program: program, date: Date.today)
      create(:program_class, program: program, date: 1.week.from_now.to_date)
      create(:program_class, program: program, date: 2.weeks.from_now.to_date)
    end

    it 'returns weekly revenue data' do
      get '/api/reports/weekly_revenue'
      expect(response).to have_http_status(:success)

      data = JSON.parse(response.body)
      expect(data).to be_an(Array)
      expect(data.length).to be > 0
    end

    it 'groups classes by week' do
      get '/api/reports/weekly_revenue'
      data = JSON.parse(response.body)

      week_data = data.first
      expect(week_data).to have_key('week_start')
      expect(week_data).to have_key('week_end')
      expect(week_data).to have_key('class_count')
      expect(week_data).to have_key('revenue')
      expect(week_data).to have_key('classes')
    end

    it 'includes class details in weekly data' do
      get '/api/reports/weekly_revenue'
      data = JSON.parse(response.body)

      week_with_classes = data.find { |w| w['classes'].any? }
      expect(week_with_classes).to be_present

      class_data = week_with_classes['classes'].first
      expect(class_data).to have_key('id')
      expect(class_data).to have_key('name')
      expect(class_data).to have_key('date')
      expect(class_data).to have_key('program_name')
      expect(class_data).to have_key('revenue')
    end

    it 'calculates revenue correctly' do
      get '/api/reports/weekly_revenue'
      data = JSON.parse(response.body)

      data.each do |week|
        expected_revenue = week['classes'].sum { |c| c['revenue'] || 0 }
        expect(week['revenue']).to eq(expected_revenue)
      end
    end

    it 'returns data for 12 weeks past and future' do
      # Create classes outside the range
      create(:program_class, program: program, date: 13.weeks.ago.to_date)
      create(:program_class, program: program, date: 13.weeks.from_now.to_date)

      get '/api/reports/weekly_revenue'
      data = JSON.parse(response.body)

      # Check that only classes within 12 weeks are included
      all_class_dates = data.flat_map { |w| w['classes'].map { |c| Date.parse(c['date']) } }

      all_class_dates.each do |date|
        expect(date).to be >= 12.weeks.ago.to_date
        expect(date).to be <= 12.weeks.from_now.to_date
      end
    end
  end
end
