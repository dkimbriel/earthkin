# frozen_string_literal: true

class UserSerializer
	def initialize(user)
	@user = user
	end

	def as_json
	{
	  id: @user.id,
	  email: @user.email,
	  role: @user.role,
	  super_admin: @user.super_admin,
	  display_name: @user.display_name,
	  teacher_id: @user.teacher&.id,
	  parent_id: @user.parent&.id,
	  created_at: @user.created_at
	}
	end
end
