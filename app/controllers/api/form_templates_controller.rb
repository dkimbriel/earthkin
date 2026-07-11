# frozen_string_literal: true

module Api
	class FormTemplatesController < BaseController
		before_action :require_admin!, except: [:index]

		def index
			FormTemplate.ensure_defaults!
			render json: FormTemplate.order(:name).as_json
		end

		def update
			template = FormTemplate.find(params[:id])
			template.update!(params.require(:form_template).permit(:name, :body))
			render json: template.as_json
		end
	end
end
