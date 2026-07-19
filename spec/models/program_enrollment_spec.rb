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

  describe 'keeping the application in sync when deactivated' do
    let(:application) { create(:enrollment_application, :enrolled) }
    let(:enrollment) do
      create(:program_enrollment, status: 'confirmed',
                                  enrollment_application: application,
                                  child: application.child,
                                  program: application.program)
    end

    context 'when the enrollment is cancelled' do
      it 'walks the enrolled application back to signing_docs' do
        enrollment.update!(status: 'cancelled', cancelled_at: Time.current)
        expect(application.reload.status).to eq('signing_docs')
      end
    end

    context 'when the enrollment is soft-deleted' do
      it 'walks the enrolled application back to signing_docs' do
        enrollment.soft_delete!
        expect(application.reload.status).to eq('signing_docs')
      end

      it 'removes the enrollment from enrolled_count' do
        enrollment # ensure it exists before measuring the count
        expect { enrollment.soft_delete! }
          .to change { application.program.reload.enrolled_count }.by(-1)
      end
    end

    context 'when the application is not enrolled' do
      let(:application) { create(:enrollment_application, :fee_paid) }

      it 'leaves the application status untouched' do
        enrollment.update!(status: 'cancelled', cancelled_at: Time.current)
        expect(application.reload.status).to eq('fee_paid')
      end
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
