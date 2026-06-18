require 'rails_helper'

RSpec.describe Location, type: :model do
  describe 'associations' do
    it { should have_many(:events).dependent(:nullify) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:address) }
  end

  describe '#full_address' do
    it 'returns name and address' do
      location = build(:location, name: 'Forest Hill Park', address: '4021 Forest Hill Ave')
      expect(location.full_address).to include('Forest Hill Park')
      expect(location.full_address).to include('4021 Forest Hill Ave')
    end
  end

  describe 'factory' do
    it 'has a valid factory' do
      location = build(:location)
      expect(location).to be_valid
    end
  end
end
