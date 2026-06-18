require 'rails_helper'

RSpec.describe EnrollmentApplication, type: :model do
  describe 'associations' do
    it { should belong_to(:program) }
    it { should belong_to(:family).optional }
    it { should belong_to(:child).optional }
    it { should have_many(:events).dependent(:destroy) }
    it { should have_one(:program_enrollment).dependent(:nullify) }
  end

  describe 'validations' do
    it { should validate_presence_of(:parent_first_name) }
    it { should validate_presence_of(:parent_last_name) }
    it { should validate_presence_of(:parent_email) }

    context 'when not invited' do
      subject { build(:enrollment_application, status: 'submitted') }

      it { should validate_presence_of(:child_first_name) }
      it { should validate_presence_of(:child_last_name) }
      it { should validate_presence_of(:child_date_of_birth) }
      it { should validate_presence_of(:child_description) }
      it { should validate_presence_of(:why_interested) }
      # Parent 2 fields are optional
      it { should validate_presence_of(:is_local) }
      it { should validate_presence_of(:referral_source) }
      it { should validate_presence_of(:parent_phone) }
    end

    context 'when invited' do
      subject { build(:enrollment_application, status: 'invited', child_first_name: nil, child_last_name: nil) }

      it { should_not validate_presence_of(:child_first_name) }
      it { should_not validate_presence_of(:child_last_name) }
    end
  end

  describe 'state transitions' do
    let(:application) { create(:enrollment_application) }

    describe '#mark_reviewed!' do
      it 'updates status to reviewed' do
        application.mark_reviewed!
        expect(application.status).to eq('reviewed')
        expect(application.reviewed_at).to be_present
      end
    end

    describe '#mark_fee_paid!' do
      it 'updates status to fee_paid' do
        application.mark_fee_paid!
        expect(application.status).to eq('fee_paid')
      end
    end

    describe '#decline!' do
      it 'updates status to declined' do
        application.decline!
        expect(application.status).to eq('declined')
        expect(application.declined_at).to be_present
      end
    end
  end

  describe 'factory' do
    it 'has a valid factory' do
      expect(build(:enrollment_application)).to be_valid
    end

    it 'creates a reviewed application' do
      application = create(:enrollment_application, :reviewed)
      expect(application.status).to eq('reviewed')
      expect(application.reviewed_at).to be_present
    end

    it 'creates an enrolled application' do
      application = create(:enrollment_application, :enrolled)
      expect(application.status).to eq('enrolled')
      expect(application.family).to be_present
      expect(application.child).to be_present
    end
  end
end
