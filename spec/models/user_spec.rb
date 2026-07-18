require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'associations' do
    it { should have_one(:teacher).dependent(:nullify) }
    it { should have_one(:parent).dependent(:nullify) }
    it { should have_many(:notification_reads).dependent(:delete_all) }
  end

  describe 'validations' do
    it { should validate_inclusion_of(:role).in_array(User::ROLES) }
  end

  describe 'role predicates' do
    it 'identifies an admin' do
      user = build(:user)
      expect(user.admin?).to be(true)
      expect(user.teacher_role?).to be(false)
      expect(user.parent_role?).to be(false)
    end

    it 'identifies a teacher' do
      user = build(:user, :teacher)
      expect(user.teacher_role?).to be(true)
      expect(user.admin?).to be(false)
    end

    it 'identifies a parent' do
      user = build(:user, :parent)
      expect(user.parent_role?).to be(true)
      expect(user.admin?).to be(false)
    end
  end

  describe '#staff?' do
    it 'is true for admins and teachers' do
      expect(build(:user).staff?).to be(true)
      expect(build(:user, :teacher).staff?).to be(true)
    end

    it 'is false for parents' do
      expect(build(:user, :parent).staff?).to be(false)
    end
  end

  describe '#display_name' do
    it "uses the linked teacher's full name when present" do
      user = create(:user, :teacher)
      create(:teacher, user: user, first_name: 'Jane', last_name: 'Smith')
      expect(user.reload.display_name).to eq('Jane Smith')
    end

    it "uses the linked parent's full name when present" do
      user = create(:user, :parent)
      create(:parent, user: user, first_name: 'John', last_name: 'Doe')
      expect(user.reload.display_name).to eq('John Doe')
    end

    it 'falls back to the email when there is no teacher or parent' do
      user = build(:user, email: 'admin@example.com')
      expect(user.display_name).to eq('admin@example.com')
    end
  end

  describe 'notification read tracking' do
    it 'deletes its notification reads when the user is destroyed' do
      user = create(:user)
      notification = Notification.create!(event_type: 'form_signed', title: 'Form signed')
      user.notification_reads.create!(notification: notification, read_at: Time.current)

      expect { user.destroy }.to change(NotificationRead, :count).by(-1)
    end
  end
end
