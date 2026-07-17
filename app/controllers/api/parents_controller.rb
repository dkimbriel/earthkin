# frozen_string_literal: true

module Api
	class ParentsController < BaseController
		def index
			parents = Parent.includes(:family).order(:last_name, :first_name)
			parents = parents.where(family_id: params[:family_id]) if params[:family_id].present?
			render json: parents.as_json(include: :family)
		end

		def show
			parent = Parent.find(params[:id])
			render json: parent.as_json(include: :family)
		end

		def create
			parent = Parent.create!(parent_params)
			render json: parent.as_json(include: :family), status: :created
		end

		def update
			parent = Parent.find(params[:id])
			parent.update!(parent_params)
			render json: parent.as_json(include: :family)
		end

		def destroy
			parent = Parent.find(params[:id])
			parent.destroy!
			head :no_content
		end

		# Create a portal login for a manually added parent and email them their
		# credentials — the same welcome email the enrollment flow sends.
		def invite
			parent = Parent.find(params[:id])

			if parent.user
				return render json: { error: "#{parent.full_name} already has a portal login (#{parent.user.email})" },
				              status: :unprocessable_content
			end

			parent.create_user_account!
			welcome = parent.emails.by_type('welcome_email').order(:created_at).last

			if welcome&.status == 'failed'
				render json: { error: "Login created, but the welcome email failed to send: #{welcome.error_message}" },
				       status: :unprocessable_content
			else
				render json: { message: "Invite sent to #{parent.email} with their login link and temporary password" }
			end
		end

		private

		def parent_params
			params.require(:parent).permit(:family_id, :first_name, :last_name, :email, :phone)
		end
	end
end
