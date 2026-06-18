require 'rails_helper'

RSpec.describe ProgramEnrollment, type: :model do
  describe 'associations' do
    it { should belong_to(:program) }
    it { should belong_to(:child) }
    it { should belong_to(:enrollment_application).optional }
    it { should have_one(:enrollment_payment_plan).dependent(:destroy) }
    it { should have_one(:payment_plan).through(:enrollment_payment_plan) }
    it { should have_many(:payments).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:status) }
  end

  describe '#advance_workflow_to!' do
    let(:enrollment) { create(:program_enrollment) }

    it 'updates workflow status' do
      enrollment.advance_workflow_to!('forms_sent')
      expect(enrollment.workflow_status).to eq('forms_sent')
    end
  end

  describe 'factory' do
    it 'has a valid factory' do
      expect(build(:program_enrollment)).to be_valid
    end

    it 'creates a cancelled enrollment' do
      enrollment = create(:program_enrollment, :cancelled)
      expect(enrollment.status).to eq('cancelled')
      expect(enrollment.cancelled_at).to be_present
    end

    it 'creates an enrollment with application' do
      enrollment = create(:program_enrollment, :with_application)
      expect(enrollment.enrollment_application).to be_present
    end
  end
end
