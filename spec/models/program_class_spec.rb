require 'rails_helper'

RSpec.describe ProgramClass, type: :model do
  describe 'associations' do
    it { should belong_to(:program) }
    it { should belong_to(:location).optional }
    it { should have_many(:program_class_teachers).dependent(:destroy) }
    it { should have_many(:teachers).through(:program_class_teachers) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:date) }
  end

  describe 'factory' do
    it 'has a valid factory' do
      program_class = build(:program_class)
      expect(program_class).to be_valid
    end
  end
end
