# frozen_string_literal: true

module Api
	class UsersController < BaseController
		before_action :require_admin!
		before_action :set_user, only: [:update, :destroy]

		def index
			users = User.includes(:teacher, :parent).order(:created_at)
			render json: users.map { |u| UserSerializer.new(u).as_json }
		end

		def create
			password = params.dig(:user, :password).presence || SecureRandom.urlsafe_base64(12)

			user = User.new(
				email: params.dig(:user, :email),
				role: params.dig(:user, :role) || 'teacher',
				password: password,
				password_confirmation: password
			)
			user.save!

			link_teacher!(user, params.dig(:user, :teacher_id))

			render json: UserSerializer.new(user).as_json, status: :created
		end

		def update
			attrs = {}
			attrs[:role] = params.dig(:user, :role) if params.dig(:user, :role).present?
			if params.dig(:user, :password).present?
				attrs[:password] = params.dig(:user, :password)
				attrs[:password_confirmation] = params.dig(:user, :password)
			end
			@user.update!(attrs)

			link_teacher!(@user, params.dig(:user, :teacher_id))

			render json: UserSerializer.new(@user).as_json
		end

		def destroy
			if @user == current_user
				return render json: { error: 'You cannot delete your own account' }, status: :unprocessable_content
			end

			@user.soft_delete!
			head :no_content
		end

		private

		def set_user
			@user = User.find(params[:id])
		end

		def link_teacher!(user, teacher_id)
			return if teacher_id.blank?

			Teacher.find(teacher_id).update!(user: user)
		end
	end
end
