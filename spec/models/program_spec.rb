require 'rails_helper'

RSpec.describe Program, type: :model do
  describe 'associations' do
    it { should have_many(:program_enrollments).dependent(:destroy) }
    it { should have_many(:program_classes).dependent(:destroy) }
    it { should have_many(:payment_plans).dependent(:destroy) }
    it { should have_many(:enrollment_applications).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:start_date) }
    it { should validate_presence_of(:end_date) }
  end

  describe 'scopes' do
    let!(:past_program) { create(:program, start_date: 2.years.ago, end_date: 1.year.ago) }
    let!(:current_program) { create(:program, start_date: 1.month.ago, end_date: 6.months.from_now) }
    let!(:future_program) { create(:program, start_date: 1.month.from_now, end_date: 1.year.from_now) }

    it 'returns current programs' do
      expect(Program.current).to include(current_program)
      expect(Program.current).not_to include(past_program)
      expect(Program.current).not_to include(future_program)
    end

    it 'returns upcoming programs' do
      expect(Program.upcoming).to include(future_program)
      expect(Program.upcoming).not_to include(current_program)
      expect(Program.upcoming).not_to include(past_program)
    end
  end

  describe '#duration_in_months' do
    it 'calculates duration correctly' do
      program = build(:program, start_date: Date.new(2026, 9, 1), end_date: Date.new(2027, 5, 31))
      expect(program.duration_in_months).to be_within(1).of(9)
    end
  end

  describe 'factory' do
    it 'has a valid factory' do
      program = build(:program)
      expect(program).to be_valid
    end
  end
end
