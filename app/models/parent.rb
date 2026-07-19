class Parent < ApplicationRecord
  include SoftDeletable

  belongs_to :family
  belongs_to :user, optional: true
  has_many :emails, as: :emailable, dependent: :destroy

  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :email, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  def full_name
    "#{first_name} #{last_name}"
  end

  def deleted_label
    "#{full_name} (#{email})"
  end

  def create_user_account!(password = nil)
    return user if user.present?

    # A live User may already exist for this email (a returning family or a
    # prior application) — link it rather than minting a duplicate.
    existing_user = User.find_by(email: email)
    if existing_user
      update!(user: existing_user)
      return existing_user
    end

    # A *soft-deleted* User with this email means this family was previously
    # deleted. Restore + link it instead of creating a duplicate (the partial
    # unique index would otherwise allow two rows for the same email), and
    # alert admins that a deleted family effectively came back.
    deleted_user = User.only_deleted.find_by(email: email)
    if deleted_user
      deleted_user.restore!
      update!(user: deleted_user)
      AdminNotifier.family_restored_from_deletion(self)
      return deleted_user
    end

    generated_password = password || SecureRandom.urlsafe_base64(12)

    new_user = User.create!(
      email: email,
      role: 'parent',
      password: generated_password,
      password_confirmation: generated_password
    )

    update!(user: new_user)

    # Send welcome email with login instructions (tracked, delivered in-process)
    EmailTrackingService.new(self).send_email('ParentMailer', 'welcome_email', [id, generated_password])

    new_user
  end
end
