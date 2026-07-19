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

		def pdf
			signature = EnrollmentFormSignature.find(params[:id])
			generator = FormSignaturePdfGenerator.new(signature)
			send_data generator.render,
			          filename: generator.filename,
			          type: 'application/pdf',
			          disposition: 'attachment'
		end

		# Manually issue the standard forms for a child (admin, outside the
		# normal workflow).
		def create
			child = Child.find(params[:child_id])
			created_any = false
			signatures = FormTemplate.ensure_defaults!.map do |form|
				signature = EnrollmentFormSignature.find_or_create_by!(child: child, form_template: form, enrollment_application: nil)
				created_any ||= signature.previously_new_record?
				signature
			end

			# Only email the family the first time forms are actually issued, so
			# re-opening the page or re-issuing doesn't spam them.
			notify_family_forms_ready(child) if created_any

			render json: signatures.as_json, status: :created
		end

		private

		# Manually issued forms skip the application queue, so email the family
		# off their program enrollment instead. Best-effort: a mail hiccup must
		# not fail the form issuance.
		def notify_family_forms_ready(child)
			enrollment = child.program_enrollments.where.not(status: 'cancelled').order(created_at: :desc).first
			return if enrollment.nil?

			parent = child.family.parents.find { |p| p.email.present? }
			return if parent.nil?

			EmailTrackingService.new(parent).send_email('EnrollmentMailer', 'enrollment_forms_notice', [enrollment.id])
		rescue StandardError => e
			Rails.logger.error("forms-ready email failed for child #{child.id}: #{e.class} #{e.message}")
		end
	end
end
