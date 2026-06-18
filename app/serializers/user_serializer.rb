# frozen_string_literal: true

class UserSerializer
	def initialize(user)
	@user = user
	end

	def as_json
	{
	  id: @user.id,
	  email: @user.email,
	  super_admin: @user.super_admin,
	  created_at: @user.created_at
	}
	end
end
