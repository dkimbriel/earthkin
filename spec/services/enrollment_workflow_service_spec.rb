require 'rails_helper'

RSpec.describe EnrollmentWorkflowService, type: :service do
  let(:application) { create(:enrollment_application) }
  let(:service) { described_class.new(application) }

  describe '#process_inquiry' do
    it 'marks application as reviewed' do
      expect(application).to receive(:mark_reviewed!)
      service.process_inquiry
    end
  end

  describe '#schedule_meeting' do
    let(:location) { create(:location) }
    let(:scheduled_at) { 1.week.from_now }

    it 'creates a meet and greet event' do
      expect {
        service.schedule_meeting(scheduled_at: scheduled_at, location_id: location.id)
      }.to change(Event, :count).by(1)

      event = application.events.last
      expect(event.event_type).to eq('meet_and_greet')
      expect(event.scheduled_at).to eq(scheduled_at)
      expect(event.location_id).to eq(location.id)
    end

    it 'updates application status' do
      service.schedule_meeting(scheduled_at: scheduled_at, location_id: location.id)
      expect(application.reload.status).to eq('meeting_scheduled')
    end

    it 'sends meeting scheduled email' do
      expect {
        service.schedule_meeting(scheduled_at: scheduled_at, location_id: location.id)
      }.to change { ActionMailer::Base.deliveries.count }.by(1)

      email = application.emails.order(:created_at).last
      expect(email.email_type).to eq('meeting_scheduled')
      expect(email.status).to eq('sent')
    end
  end

  describe '#complete_meeting' do
    let!(:event) { create(:event, eventable: application, event_type: 'meet_and_greet') }

    before do
      # Prevent auto-advance to fee_requested for these tests
      allow(service).to receive(:auto_advance?).and_return(false)
    end

    it 'completes the event' do
      service.complete_meeting(event.id, outcome_notes: 'Great meeting!')
      expect(event.reload.status).to eq('completed')
      expect(event.outcome_notes).to eq('Great meeting!')
    end

    it 'updates application status' do
      service.complete_meeting(event.id)
      expect(application.reload.status).to eq('meeting_completed')
    end
  end

  describe '#request_enrollment_fee' do
    it 'updates application status' do
      service.request_enrollment_fee
      expect(application.reload.status).to eq('fee_requested')
    end

    it 'sends enrollment fee request email' do
      expect {
        service.request_enrollment_fee
      }.to change { ActionMailer::Base.deliveries.count }.by(1)

      email = application.emails.order(:created_at).last
      expect(email.email_type).to eq('enrollment_fee_request')
      expect(email.status).to eq('sent')
    end
  end

  describe '#process_enrollment_fee_payment' do
    let(:payment_plan) { create(:payment_plan, program: application.program) }
    let(:payment_params) do
      {
        payment_plan_id: payment_plan.id,
        payment_method: 'venmo',
        payment_date: Date.today
      }
    end

    context 'when family does not exist' do
      it 'creates family, parent, and child records' do
        expect {
          service.process_enrollment_fee_payment(**payment_params)
        }.to change(Family, :count).by(1)
          .and change(Parent, :count).by(1)
          .and change(Child, :count).by(1)
      end

      it 'associates records with application' do
        service.process_enrollment_fee_payment(**payment_params)
        application.reload

        expect(application.family).to be_present
        expect(application.child).to be_present
        expect(application.family.parents.first.email).to eq(application.parent_email)
      end
    end

    context 'when family already exists' do
      let!(:family) { create(:family, name: application.parent_last_name) }
      let!(:parent) { create(:parent, family: family, email: application.parent_email) }

      it 'reuses existing family and parent' do
        initial_family_count = Family.count
        initial_parent_count = Parent.count

        service.process_enrollment_fee_payment(**payment_params)

        expect(Family.count).to eq(initial_family_count)
        expect(Parent.count).to eq(initial_parent_count)
      end

      it 'creates child for existing family' do
        expect {
          service.process_enrollment_fee_payment(**payment_params)
        }.to change(Child, :count).by(1)
      end
    end

    it 'creates program enrollment' do
      expect {
        service.process_enrollment_fee_payment(**payment_params)
      }.to change(ProgramEnrollment, :count).by(1)

      enrollment = ProgramEnrollment.last
      expect(enrollment.enrollment_application).to eq(application)
      expect(enrollment.workflow_status).to eq('fee_paid')
    end

    it 'creates enrollment payment plan' do
      expect {
        service.process_enrollment_fee_payment(**payment_params)
      }.to change(EnrollmentPaymentPlan, :count).by(1)

      epp = EnrollmentPaymentPlan.last
      expect(epp.payment_plan).to eq(payment_plan)
      expect(epp.enrollment_fee_paid).to be true
    end

    it 'creates enrollment fee payment' do
      expect {
        service.process_enrollment_fee_payment(**payment_params)
      }.to change(Payment, :count).by(1)

      payment = Payment.last
      expect(payment.payment_type).to eq('enrollment_fee')
      expect(payment.amount).to eq(150.0)
      expect(payment.payment_method).to eq('venmo')
    end

    it 'updates application status to fee_paid' do
      service.process_enrollment_fee_payment(**payment_params)
      expect(application.reload.status).to eq('fee_paid')
    end
  end
end
