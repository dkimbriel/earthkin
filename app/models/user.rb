class User < ApplicationRecord
	# Include default devise modules. Others available are:
	# :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
	devise :database_authenticatable, :registerable,
		 :recoverable, :rememberable, :validatable

	ROLES = %w[admin teacher parent].freeze

	has_one :teacher, dependent: :nullify
	has_one :parent, dependent: :nullify

	validates :role, inclusion: { in: ROLES }

	def admin?
		role == 'admin'
	end

	def teacher_role?
		role == 'teacher'
	end

	def parent_role?
		role == 'parent'
	end

	# Staff (admins and teachers) may access the internal portal APIs.
	def staff?
		admin? || teacher_role?
	end

	def display_name
		teacher&.full_name || parent&.full_name || email
	end
end
