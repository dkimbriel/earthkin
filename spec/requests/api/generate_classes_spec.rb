require 'rails_helper'

RSpec.describe 'Api::Programs generate_classes', type: :request do
  let(:admin) { create(:user) }
  let(:program) do
    create(:program,
           start_date: Date.new(2026, 9, 1),  # a Tuesday
           end_date: Date.new(2026, 9, 30),
           class_days: 'Tuesday & Thursday')
  end

  before { sign_in admin }

  it 'creates classes on the pattern days between program dates' do
    expect {
      post "/api/programs/#{program.id}/generate_classes"
    }.to change(ProgramClass, :count).by(9) # Sep 2026: 5 Tuesdays (1,8,15,22,29) + 4 Thursdays (3,10,17,24)

    expect(response).to have_http_status(:created)
    json = JSON.parse(response.body)
    expect(json['created_count']).to eq(9)
    expect(program.program_classes.pluck(:date)).to all(satisfy { |d| [2, 4].include?(d.wday) })
  end

  it 'skips holidays and existing class dates' do
    create(:program_class, program: program, date: Date.new(2026, 9, 1))

    post "/api/programs/#{program.id}/generate_classes", params: {
      skip_dates: '2026-09-03, 2026-09-08'
    }

    json = JSON.parse(response.body)
    expect(json['created_count']).to eq(6) # 9 minus existing 9/1, skipped 9/3 and 9/8
  end

  it 'accepts explicit days and date range' do
    post "/api/programs/#{program.id}/generate_classes", params: {
      days_of_week: ['friday'],
      start_date: '2026-09-01',
      end_date: '2026-09-15'
    }

    json = JSON.parse(response.body)
    expect(json['created_count']).to eq(2) # Fridays 9/4 and 9/11
  end

  it 'errors when no days can be determined' do
    program.update!(class_days: nil)

    post "/api/programs/#{program.id}/generate_classes"

    expect(response).to have_http_status(:unprocessable_content)
  end
end
