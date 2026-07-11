# frozen_string_literal: true

module Api
	class EnrollmentFormSignaturesController < BaseController
		# Staff view of a family's paperwork, grouped client-side by child.
		def index
			signatures = EnrollmentFormSignature.includes(:child, :form_template)
			if params[:family_id].present?
				signatures = signatures.where(child_id: Family.find(params[:family_id]).children.select(:id))
			elsif params[:child_id].present?
				signatures = signatures.where(child_id: params[:child_id])
			end

			render json: signatures.order(:created_at).map { |s|
				s.as_json.merge(form_body_snapshot: s.form_body_snapshot)
			}
		end

		# Manually issue the standard forms for a child (admin, outside the
		# normal workflow).
		def create
			child = Child.find(params[:child_id])
			signatures = FormTemplate.ensure_defaults!.map do |form|
				EnrollmentFormSignature.find_or_create_by!(child: child, form_template: form, enrollment_application: nil)
			end

			render json: signatures.as_json, status: :created
		end
	end
end
