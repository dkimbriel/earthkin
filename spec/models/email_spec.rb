require 'rails_helper'

RSpec.describe Email, type: :model do
  describe 'associations' do
    it { should belong_to(:emailable).optional }
  end

  describe 'validations' do
    it { should validate_presence_of(:email_type) }
    it { should validate_presence_of(:recipient) }
    it { should validate_presence_of(:subject) }
    it { should validate_inclusion_of(:status).in_array(%w[queued sent failed bounced]) }
    it { should validate_inclusion_of(:mailer_class).in_array(%w[EnrollmentMailer PaymentMailer ParentMailer]) }
  end

  describe 'scopes' do
    let(:application) { create(:enrollment_application) }
    let!(:sent_email) { create(:email, :sent, emailable: application) }
    let!(:failed_email) { create(:email, :failed, emailable: application) }
    let!(:queued_email) { create(:email, emailable: application) }

    it 'filters by sent status' do
      expect(Email.sent).to include(sent_email)
      expect(Email.sent).not_to include(failed_email)
    end

    it 'filters by failed status' do
      expect(Email.failed).to include(failed_email)
      expect(Email.failed).not_to include(sent_email)
    end

    it 'filters by type' do
      expect(Email.by_type('inquiry_response')).to include(sent_email)
    end

    it 'filters by mailer class' do
      expect(Email.for_mailer('EnrollmentMailer')).to include(sent_email)
    end

    it 'orders by recent' do
      expect(Email.recent.first).to eq(queued_email)
    end
  end

  describe '#mark_sent!' do
    let(:email) { create(:email) }

    it 'marks email as sent' do
      email.mark_sent!
      expect(email.status).to eq('sent')
      expect(email.sent_at).to be_present
    end
  end

  describe '#mark_failed!' do
    let(:email) { create(:email) }

    it 'marks email as failed with error message' do
      email.mark_failed!('Connection timeout')
      expect(email.status).to eq('failed')
      expect(email.failed_at).to be_present
      expect(email.error_message).to include('Connection timeout')
    end
  end

  describe '#type_label' do
    it 'returns titleized email type' do
      email = build(:email, email_type: 'inquiry_response')
      expect(email.type_label).to eq('Inquiry Response')
    end
  end

  describe '#status_color' do
    it 'returns success for sent' do
      email = build(:email, :sent)
      expect(email.status_color).to eq('success')
    end

    it 'returns error for failed' do
      email = build(:email, :failed)
      expect(email.status_color).to eq('error')
    end

    it 'returns warning for queued' do
      email = build(:email, status: 'queued')
      expect(email.status_color).to eq('warning')
    end

    it 'returns error for bounced' do
      email = build(:email, status: 'bounced')
      expect(email.status_color).to eq('error')
    end
  end

  describe 'factory' do
    it 'has a valid factory' do
      email = build(:email)
      expect(email).to be_valid
    end

    it 'has valid trait for_payment' do
      email = build(:email, :for_payment)
      expect(email).to be_valid
      expect(email.mailer_class).to eq('PaymentMailer')
    end

    it 'has valid trait for_parent' do
      email = build(:email, :for_parent)
      expect(email).to be_valid
      expect(email.mailer_class).to eq('ParentMailer')
    end
  end
end
