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
			# If a deleted parent (or their portal user) has this email, offer to
			# restore it instead of silently creating a duplicate. `force: true`
			# skips the check and creates a fresh record.
			unless ActiveModel::Type::Boolean.new.cast(params[:force])
				existing = deleted_match_for(params.dig(:parent, :email))
				if existing
					return render json: {
						error: "A deleted record for #{existing.deleted_label} exists.",
						restorable: {
							type: existing.class.name,
							id: existing.id,
							label: existing.deleted_label,
							deleted_at: existing.deleted_at
						}
					}, status: :conflict
				end
			end

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
			parent.soft_delete!
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

		# A soft-deleted record matching this email signals a previously-deleted
		# family. Return the best thing to restore: the whole original family if it
		# was deleted too, otherwise the matched parent/user itself.
		def deleted_match_for(email)
			return nil if email.blank?

			match = Parent.only_deleted.find_by(email: email) || User.only_deleted.find_by(email: email)
			return nil if match.nil?

			family_id = match.is_a?(Parent) ? match.family_id : Parent.with_deleted.find_by(user_id: match.id)&.family_id
			family = family_id && Family.only_deleted.find_by(id: family_id)
			family || match
		end

		def parent_params
			params.require(:parent).permit(:family_id, :first_name, :last_name, :email, :phone)
		end
	end
end
