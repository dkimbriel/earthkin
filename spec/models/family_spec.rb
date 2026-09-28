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

  describe '#emails' do
    let(:family) { create(:family) }
    let(:child) { create(:child, family: family) }
    let(:parent) { create(:parent, family: family) }
    let(:enrollment) { create(:program_enrollment, child: child) }
    let(:application) { create(:enrollment_application, family: family) }
    let(:child_only_application) { create(:enrollment_application, child: child) }

    it 'collects emails logged on applications, parents, and payments' do
      app_email = create(:email, :sent, emailable: application)
      child_app_email = create(:email, :sent, emailable: child_only_application)
      parent_email = create(:email, :for_parent, :sent, emailable: parent)
      payment_email = create(:email, :for_payment, :sent, emailable: create(:payment, program_enrollment: enrollment))

      expect(family.emails).to contain_exactly(app_email, child_app_email, parent_email, payment_email)
    end

    it "excludes drafts, soft-deleted emails, and other families' emails" do
      create(:email, emailable: application, status: 'draft')
      create(:email, :sent, emailable: application).soft_delete!
      create(:email, :sent, emailable: create(:enrollment_application, family: create(:family)))

      expect(family.emails).to be_empty
    end

    it 'orders newest first by sent time, falling back to created time' do
      older = create(:email, :sent, emailable: application, sent_at: 2.days.ago)
      queued = create(:email, emailable: application, status: 'queued', sent_at: nil)
      newer = create(:email, :sent, emailable: application, sent_at: 1.hour.from_now)

      expect(family.emails).to eq([newer, queued, older])
    end
  end
end
