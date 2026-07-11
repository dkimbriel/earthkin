# frozen_string_literal: true

module Api
	class EmailTemplatesController < BaseController
		before_action :require_admin!
		before_action :set_template, only: [:update, :destroy]

		def index
			templates = EmailTemplate.order(:name)
			render json: {
				templates: templates.as_json,
				# Workflow emails that can be overridden and their placeholders
				known_keys: EmailTemplate::KNOWN_KEYS
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
			params.require(:email_template).permit(:key, :name, :subject, :body).tap do |p|
				p[:key] = nil if p[:key].blank?
			end
		end
	end
end
