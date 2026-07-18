require 'rails_helper'

RSpec.describe AdminNotifier do
  let(:program) { create(:program) }
  let(:application) do
    create(:enrollment_application, program: program,
                                    parent_first_name: 'Dana', parent_last_name: 'Rivera',
                                    child_first_name: 'Sam', child_last_name: 'Rivera')
  end

  describe '.payment_plan_selected' do
    it 'creates an in-app notification tied to the application' do
      plan = create(:payment_plan, program: program, name: 'Monthly')

      expect {
        described_class.payment_plan_selected(application, plan)
      }.to change(Notification, :count).by(1)

      notification = Notification.last
      expect(notification.event_type).to eq('payment_plan_selected')
      expect(notification.title).to include('Sam Rivera')
      expect(notification.body).to include('Monthly')
      expect(notification.enrollment_application).to eq(application)
    end
  end

  describe '.alert_address' do
    it 'plus-aliases the connected mailbox' do
      allow(GmailIntegration).to receive(:current).and_return(double(email: 'school@gmail.com'))
      expect(described_class.alert_address).to eq('school+alerts@gmail.com')
    end

    it 'is nil when no mailbox is connected' do
      allow(GmailIntegration).to receive(:current).and_return(nil)
      expect(described_class.alert_address).to be_nil
    end
  end

  describe 'resilience' do
    it 'does not raise when email delivery fails' do
      plan = create(:payment_plan, program: program)
      allow(AdminNotificationMailer).to receive(:alert).and_raise(StandardError, 'gmail down')
      allow(described_class).to receive(:alert_address).and_return('school+alerts@gmail.com')

      expect {
        described_class.payment_plan_selected(application, plan)
      }.to change(Notification, :count).by(1)
    end
  end
end
