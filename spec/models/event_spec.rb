require 'rails_helper'

RSpec.describe Event, type: :model do
  describe 'associations' do
    it { should belong_to(:eventable).optional }
    it { should belong_to(:location).optional }
  end

  describe 'validations' do
    it { should validate_presence_of(:event_type) }
    it { should validate_presence_of(:scheduled_at) }
    it do
      should validate_inclusion_of(:event_type).in_array(
        %w[meet_and_greet orientation field_trip parent_meeting]
      )
    end
  end

  describe 'state transitions' do
    let(:event) { create(:event) }

    describe '#confirm!' do
      it 'updates status to confirmed' do
        event.confirm!
        expect(event.status).to eq('confirmed')
      end
    end

    describe '#complete!' do
      it 'updates status to completed' do
        event.complete!
        expect(event.status).to eq('completed')
        expect(event.completed_at).to be_present
      end
    end

    describe '#cancel!' do
      it 'updates status to cancelled' do
        event.cancel!
        expect(event.status).to eq('cancelled')
        expect(event.cancelled_at).to be_present
      end
    end
  end

  describe 'polymorphic association' do
    it 'can belong to an enrollment application' do
      application = create(:enrollment_application)
      event = create(:event, eventable: application)
      expect(event.eventable).to eq(application)
      expect(event.eventable_type).to eq('EnrollmentApplication')
    end
  end
end
