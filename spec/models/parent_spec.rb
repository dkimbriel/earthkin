require 'rails_helper'

RSpec.describe Parent, type: :model do
  describe 'associations' do
    it { should belong_to(:family) }
    it { should belong_to(:user).optional }
  end

  describe 'validations' do
    it { should validate_presence_of(:first_name) }
    it { should validate_presence_of(:last_name) }
    it { should validate_presence_of(:email) }
  end

  describe '#full_name' do
    it 'returns first and last name' do
      parent = build(:parent, first_name: 'John', last_name: 'Doe')
      expect(parent.full_name).to eq('John Doe')
    end
  end
end
