class Parent < ApplicationRecord
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

  def create_user_account!(password = nil)
    return user if user.present?

    generated_password = password || SecureRandom.urlsafe_base64(12)

    new_user = User.create!(
      email: email,
      password: generated_password,
      password_confirmation: generated_password
    )

    update!(user: new_user)

    # Send welcome email with login instructions (tracked, delivered in-process)
    EmailTrackingService.new(self).send_email('ParentMailer', 'welcome_email', [id, generated_password])

    new_user
  end
end
