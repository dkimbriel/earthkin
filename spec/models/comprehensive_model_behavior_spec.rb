require 'rails_helper'

RSpec.describe 'Comprehensive Model Behaviors', type: :model do
  describe EnrollmentApplication do
    let(:application) { create(:enrollment_application) }

    describe 'state transitions' do
      it 'transitions from submitted to reviewed' do
        application.update!(status: 'submitted')
        application.mark_reviewed!
        expect(application.status).to eq('reviewed')
        expect(application.reviewed_at).to be_present
      end

      it 'transitions through all workflow states' do
        application.schedule_meeting!
        expect(application.status).to eq('meeting_scheduled')

        application.complete_meeting!
        expect(application.status).to eq('meeting_completed')

        application.request_enrollment_fee!
        expect(application.status).to eq('fee_requested')

        application.mark_fee_paid!
        expect(application.status).to eq('fee_paid')

        application.enroll!
        expect(application.status).to eq('enrolled')
      end

      it 'records declined timestamp when declined' do
        application.decline!('Not a good fit')
        expect(application.status).to eq('declined')
        expect(application.declined_at).to be_present
        expect(application.admin_notes).to include('Not a good fit')
      end

      it 'appends notes when declining with existing notes' do
        application.update!(admin_notes: 'Previous notes')
        application.decline!('New reason')
        expect(application.admin_notes).to include('Previous notes')
        expect(application.admin_notes).to include('New reason')
      end
    end

    describe 'helper methods' do
      it 'returns full child name' do
        app = build(:enrollment_application, child_first_name: 'Emma', child_last_name: 'Smith')
        expect(app.full_child_name).to eq('Emma Smith')
      end

      it 'returns full parent name' do
        app = build(:enrollment_application, parent_first_name: 'John', parent_last_name: 'Doe')
        expect(app.full_parent_name).to eq('John Doe')
      end

      it 'finds meet and greet event' do
        event = create(:event, eventable: application, event_type: 'meet_and_greet')
        expect(application.meet_and_greet).to eq(event)
      end

      it 'returns nil if no meet and greet exists' do
        expect(application.meet_and_greet).to be_nil
      end
    end

    describe 'phone normalization' do
      it 'normalizes 10-digit phone number' do
        app = create(:enrollment_application, parent_phone: '5551234567')
        expect(app.parent_phone).to eq('(555) 123-4567')
      end

      it 'keeps already formatted phone numbers' do
        app = create(:enrollment_application, parent_phone: '(555) 123-4567')
        expect(app.parent_phone).to eq('(555) 123-4567')
      end

      it 'handles blank phone numbers' do
        app = create(:enrollment_application, parent_phone: nil)
        expect(app.parent_phone).to be_nil
      end

      it 'does not normalize invalid phone numbers' do
        app = build(:enrollment_application, parent_phone: '12345')
        app.save(validate: false)
        expect(app.parent_phone).to eq('12345')
      end
    end

    describe 'scopes' do
      before do
        create(:enrollment_application, status: 'submitted')
        create(:enrollment_application, status: 'submitted')
        create(:enrollment_application, :reviewed)
        create(:enrollment_application, :enrolled, status: 'enrolled')
        create(:enrollment_application, status: 'declined')
      end

      it 'filters pending review' do
        expect(EnrollmentApplication.pending_review.count).to eq(2)
      end

      it 'filters awaiting meeting' do
        expect(EnrollmentApplication.awaiting_meeting.count).to eq(1)
      end

      it 'filters active applications' do
        active = EnrollmentApplication.active
        expect(active).not_to include(EnrollmentApplication.find_by(status: 'enrolled'))
        expect(active).not_to include(EnrollmentApplication.find_by(status: 'declined'))
      end
    end
  end

  describe EnrollmentPaymentPlan do
    let(:enrollment) { create(:program_enrollment) }
    let(:payment_plan) { create(:payment_plan, :monthly, program: enrollment.program) }
    let(:enrollment_payment_plan) { create(:enrollment_payment_plan, :fee_paid, :with_monthly_plan, program_enrollment: enrollment, payment_plan: payment_plan) }

    describe '#next_installment' do
      it 'returns the first pending installment' do
        next_inst = enrollment_payment_plan.next_installment
        expect(next_inst).to be_present
        expect(next_inst['status']).to eq('pending')
      end

      it 'skips paid installments' do
        installments = enrollment_payment_plan.installments
        installments.first['status'] = 'paid'
        enrollment_payment_plan.update!(installments: installments)

        next_inst = enrollment_payment_plan.next_installment
        expect(next_inst).to eq(installments.second)
      end
    end

    describe '#overdue_installments' do
      before do
        installments = enrollment_payment_plan.installments
        installments.first['due_date'] = 2.months.ago.to_date.to_s
        installments.first['status'] = 'pending'
        enrollment_payment_plan.update!(installments: installments)
      end

      it 'returns installments past due date' do
        overdue = enrollment_payment_plan.overdue_installments
        expect(overdue.length).to be > 0
        expect(Date.parse(overdue.first['due_date'])).to be < Date.today
      end

      it 'only returns pending overdue installments' do
        overdue = enrollment_payment_plan.overdue_installments
        overdue.each do |inst|
          expect(inst['status']).to eq('pending')
        end
      end
    end

    describe '#mark_enrollment_fee_paid!' do
      let(:plan) { create(:enrollment_payment_plan, program_enrollment: enrollment, payment_plan: payment_plan) }

      it 'marks fee as paid and records timestamp' do
        plan.mark_enrollment_fee_paid!
        expect(plan.enrollment_fee_paid).to be true
        expect(plan.enrollment_fee_paid_at).to be_present
      end
    end
  end

  describe Event do
    let(:application) { create(:enrollment_application) }
    let(:event) { create(:event, eventable: application) }

    describe 'state transitions' do
      it 'confirms event' do
        event.confirm!
        expect(event.status).to eq('confirmed')
      end

      it 'completes event with notes' do
        event.complete!('Went well')
        expect(event.status).to eq('completed')
        expect(event.completed_at).to be_present
        expect(event.outcome_notes).to eq('Went well')
      end

      it 'cancels event with reason' do
        event.cancel!('Family emergency')
        expect(event.status).to eq('cancelled')
        expect(event.cancelled_at).to be_present
      end
    end

    describe 'polymorphic association' do
      it 'belongs to enrollment application' do
        expect(event.eventable).to eq(application)
        expect(event.eventable_type).to eq('EnrollmentApplication')
      end
    end
  end

  describe Payment do
    let(:enrollment) { create(:program_enrollment) }

    describe 'scopes' do
      before do
        create(:payment, :enrollment_fee, program_enrollment: enrollment)
        create(:payment, program_enrollment: enrollment, payment_type: 'tuition')
        create(:payment, program_enrollment: enrollment, payment_type: 'tuition')
      end

      it 'filters enrollment fees' do
        expect(Payment.enrollment_fees.count).to eq(1)
      end

      it 'filters tuition payments' do
        expect(Payment.tuition_payments.count).to eq(2)
      end
    end
  end

  describe PaymentPlan do
    let(:program) { create(:program) }
    let(:plan) { create(:payment_plan, program: program, total_amount: 1000, installment_count: 4) }

    describe 'scopes' do
      before do
        create_list(:payment_plan, 2, program: program, active: true)
        create(:payment_plan, program: program, active: false)
      end

      it 'filters by active and orders by display_order' do
        active_plans = PaymentPlan.active
        expect(active_plans.count).to eq(2)
        expect(active_plans.all?(&:active)).to be true
      end
    end

    describe 'installment calculation callback' do
      it 'calculates installment amount on save' do
        expect(plan.installment_amount).to eq(250.0)
      end

      it 'recalculates when total_amount changes' do
        plan.update!(total_amount: 2000)
        expect(plan.installment_amount).to eq(500.0)
      end

      it 'recalculates when installment_count changes' do
        plan.update!(installment_count: 10)
        expect(plan.installment_amount).to eq(100.0)
      end
    end
  end

  describe Parent do
    let(:family) { create(:family) }

    describe '#create_user_account!' do
      let(:parent) { create(:parent, family: family, email: 'test@example.com', user: nil) }

      before do
        allow(ParentMailer).to receive_message_chain(:welcome_email, :deliver_later)
      end

      it 'creates a user account for the parent' do
        expect {
          parent.create_user_account!('password123')
        }.to change(User, :count).by(1)

        expect(parent.user).to be_present
        expect(parent.user.email).to eq('test@example.com')
      end

      it 'returns existing user if already created' do
        user = parent.create_user_account!('password123')
        same_user = parent.create_user_account!('password123')

        expect(same_user).to eq(user)
      end

      it 'sends welcome email' do
        expect(ParentMailer).to receive(:welcome_email)
          .with(parent.id, kind_of(String))
          .and_return(double(deliver_later: true))

        parent.create_user_account!
      end

      it 'generates password if not provided' do
        parent.create_user_account!

        expect(parent.user).to be_present
        expect(parent.user.valid_password?('wrong')).to be false
      end
    end
  end
end
