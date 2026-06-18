require 'rails_helper'

RSpec.describe Teacher, type: :model do
  describe 'associations' do
    it { should belong_to(:user).optional }
    it { should have_many(:program_class_teachers).dependent(:destroy) }
    it { should have_many(:program_classes).through(:program_class_teachers) }
  end

  describe 'validations' do
    it { should validate_presence_of(:first_name) }
    it { should validate_presence_of(:last_name) }
    it { should validate_presence_of(:email) }
  end

  describe '#full_name' do
    it 'returns first and last name' do
      teacher = build(:teacher, first_name: 'Jane', last_name: 'Smith')
      expect(teacher.full_name).to eq('Jane Smith')
    end
  end

  describe 'factory' do
    it 'has a valid factory' do
      teacher = build(:teacher)
      expect(teacher).to be_valid
    end
  end
end
