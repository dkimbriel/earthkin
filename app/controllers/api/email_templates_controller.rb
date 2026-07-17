# frozen_string_literal: true

module Api
	class EmailTemplatesController < BaseController
		before_action :require_admin!
		before_action :set_template, only: [:update, :destroy]

		def index
			EmailTemplate.ensure_defaults!
			templates = EmailTemplate.order(:name)
			render json: {
				templates: templates.as_json,
				# Workflow emails and the tokens each supports
				known_keys: EmailTemplate::KNOWN_KEYS,
				token_info: EmailTemplate::TOKEN_INFO
			}
		end

		def create
			template = EmailTemplate.create!(template_params)
			render json: template.as_json, status: :created
		end

		def update
			@template.update!(template_params)
			render json: @template.as_json
		end

		def destroy
			@template.destroy!
			head :no_content
		end

		private

		def set_template
			@template = EmailTemplate.find(params[:id])
		end

		def template_params
			permitted = params.require(:email_template).permit(:key, :name, :subject, :body)
			# Normalize a blank key to nil, but only when the caller sent one —
			# a body-only update must not detach the template from its workflow.
			permitted[:key] = nil if permitted.key?(:key) && permitted[:key].blank?
			permitted
		end
	end
end
