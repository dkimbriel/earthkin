require 'rails_helper'

RSpec.describe Child, type: :model do
  describe 'associations' do
    it { should belong_to(:family) }
    it { should have_many(:program_enrollments).dependent(:destroy) }
    it { should have_many(:programs).through(:program_enrollments) }
    it { should have_many(:enrollment_applications).dependent(:nullify) }
  end

  describe 'validations' do
    it { should validate_presence_of(:first_name) }
    it { should validate_presence_of(:last_name) }
  end

  describe '#full_name' do
    it 'returns first and last name' do
      child = build(:child, first_name: 'Emma', last_name: 'Smith')
      expect(child.full_name).to eq('Emma Smith')
    end
  end

  describe 'factory' do
    it 'has a valid factory' do
      child = build(:child)
      expect(child).to be_valid
    end
  end
end
