require 'rails_helper'

RSpec.describe Family, type: :model do
  describe 'associations' do
    it { should have_many(:parents).dependent(:destroy) }
    it { should have_many(:children).dependent(:destroy) }
    it { should have_many(:enrollment_applications).dependent(:nullify) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
  end

  describe '#full_name' do
    it 'returns the family name' do
      family = build(:family, name: 'Smith')
      expect(family.full_name).to eq('Smith Family')
    end
  end

  describe '#primary_parent' do
    it 'returns the first parent' do
      family = create(:family)
      parent1 = create(:parent, family: family, email: 'first@example.com')
      parent2 = create(:parent, family: family, email: 'second@example.com')

      expect(family.primary_parent).to eq(parent1)
    end
  end
end
