require 'rails_helper'

RSpec.describe ProgramEnrollment, type: :model do
  describe '#advance_workflow_to!' do
    let(:enrollment) { create(:program_enrollment, workflow_status: 'application_submitted') }

    it 'updates workflow status' do
      enrollment.advance_workflow_to!('meeting_scheduled')
      expect(enrollment.workflow_status).to eq('meeting_scheduled')
    end

    it 'progresses through workflow stages' do
      enrollment.advance_workflow_to!('meeting_scheduled')
      enrollment.advance_workflow_to!('meeting_completed')
      enrollment.advance_workflow_to!('fee_requested')
      enrollment.advance_workflow_to!('fee_paid')
      enrollment.advance_workflow_to!('forms_sent')
      enrollment.advance_workflow_to!('enrolled')

      expect(enrollment.workflow_status).to eq('enrolled')
    end
  end

  describe 'payment plan association' do
    let(:program) { create(:program) }
    let(:payment_plan) { create(:payment_plan, program: program) }
    let(:enrollment) { create(:program_enrollment, program: program) }
    let(:enrollment_payment_plan) { create(:enrollment_payment_plan, program_enrollment: enrollment, payment_plan: payment_plan) }

    it 'accesses payment plan through enrollment_payment_plan' do
      enrollment_payment_plan
      expect(enrollment.payment_plan).to eq(payment_plan)
    end
  end

  describe 'payments association' do
    let(:enrollment) { create(:program_enrollment) }

    it 'has many payments' do
      create_list(:payment, 3, program_enrollment: enrollment)
      expect(enrollment.payments.count).to eq(3)
    end

    it 'destroys payments when enrollment is deleted' do
      create_list(:payment, 2, program_enrollment: enrollment)
      enrollment_id = enrollment.id

      expect {
        enrollment.destroy
      }.to change(Payment, :count).by(-2)
    end
  end

  describe 'with enrollment application' do
    let(:application) { create(:enrollment_application) }
    let(:enrollment) { create(:program_enrollment, :with_application, enrollment_application: application) }

    it 'links to enrollment application' do
      expect(enrollment.enrollment_application).to eq(application)
    end
  end

  describe 'scopes and queries' do
    let(:program) { create(:program) }
    let!(:active_enrollment) { create(:program_enrollment, program: program, status: 'active') }
    let!(:withdrawn_enrollment) { create(:program_enrollment, program: program, status: 'withdrawn') }
    let!(:cancelled_enrollment) { create(:program_enrollment, :cancelled, program: program) }

    it 'filters by status' do
      expect(ProgramEnrollment.where(status: 'active')).to include(active_enrollment)
      expect(ProgramEnrollment.where(status: 'active')).not_to include(withdrawn_enrollment)
    end

    it 'filters by program' do
      other_program = create(:program)
      other_enrollment = create(:program_enrollment, program: other_program)

      program_enrollments = ProgramEnrollment.where(program: program)
      expect(program_enrollments).to include(active_enrollment)
      expect(program_enrollments).not_to include(other_enrollment)
    end
  end

  describe 'with child and family' do
    let(:family) { create(:family) }
    let(:child) { create(:child, family: family) }
    let(:enrollment) { create(:program_enrollment, child: child) }

    it 'accesses family through child' do
      expect(enrollment.child.family).to eq(family)
    end
  end
end
