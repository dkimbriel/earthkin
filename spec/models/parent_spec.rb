require 'rails_helper'

RSpec.describe Parent, type: :model do
  describe 'associations' do
    it { should belong_to(:family) }
    it { should belong_to(:user).optional }
  end

  describe 'validations' do
    it { should validate_presence_of(:first_name) }
    it { should validate_presence_of(:last_name) }
    it { should validate_presence_of(:email) }
  end

  describe '#full_name' do
    it 'returns first and last name' do
      parent = build(:parent, first_name: 'John', last_name: 'Doe')
      expect(parent.full_name).to eq('John Doe')
    end
  end

  describe '#create_user_account!' do
    it 'restores and links a soft-deleted user with the same email, and notifies admins' do
      old_user = create(:user, :parent, email: 'return@example.com')
      old_user.soft_delete!

      parent = create(:parent, email: 'return@example.com')

      expect {
        parent.create_user_account!
      }.to change(Notification.where(event_type: 'family_restored_from_deletion'), :count).by(1)

      expect(parent.reload.user).to eq(old_user)
      expect(old_user.reload).not_to be_deleted
      # No duplicate user was created for the email.
      expect(User.with_deleted.where(email: 'return@example.com').count).to eq(1)
    end

    it 'creates a fresh account when no matching user exists' do
      parent = create(:parent, email: 'brand.new@example.com')
      expect { parent.create_user_account! }.to change(User, :count).by(1)
    end
  end
end
