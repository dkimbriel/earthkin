# frozen_string_literal: true

module Api
	# Staff documents: written warnings, performance notices, termination
	# letters. Deliberately not under BaseController. That controller makes
	# every teacher endpoint view-only, which is right for the rest of the
	# internal API, and signing your own notice is the one place a teacher must
	# be able to write. Authorization is spelled out here instead: admins issue
	# and counter-sign, an employee reads and signs their own documents and
	# nobody else's.
	class StaffDocumentsController < ApplicationController
		before_action :authenticate_user!
		before_action :require_staff!
		before_action :require_admin!, only: %i[create templates]

		rescue_from ActiveRecord::RecordNotFound, with: -> { render json: { error: 'Record not found' }, status: :not_found }

		def index
			documents = scoped_documents.includes(:teacher, :issued_by).order(created_at: :desc)
			documents = documents.where(teacher_id: params[:teacher_id]) if params[:teacher_id].present? && current_user.admin?

			render json: documents.map(&:as_json)
		end

		def show
			render json: owned_document.as_json
		end

		# Issue a document to an employee (admin only). The body is resolved and
		# copied onto the record here, so later template edits leave it alone.
		def create
			template = FormTemplate.staff.find_by(id: params[:form_template_id])
			document = StaffDocument.issue!(
				teacher: Teacher.find(params[:teacher_id]),
				issued_by: current_user,
				form_template: template,
				title: params[:title],
				body: params[:body],
				employee_position: params[:employee_position]
			)

			render json: document.as_json, status: :created
		rescue ActiveRecord::RecordInvalid => e
			render json: { errors: e.record.errors.full_messages }, status: :unprocessable_content
		end

		# The templates an admin can start a new document from.
		def templates
			FormTemplate.ensure_staff_defaults!
			render json: {
				templates: FormTemplate.staff.order(:name).as_json,
				known_tokens: FormTemplate::STAFF_TOKENS,
				token_info: FormTemplate::STAFF_TOKEN_INFO,
				teachers: Teacher.order(:last_name).map { |t| { id: t.id, name: t.full_name, email: t.email } }
			}
		end

		# One endpoint, two signatures: a teacher signing their own notice is
		# acknowledging receipt, an admin signing is counter-signing it.
		def sign
			document = owned_document

			if current_user.admin?
				document.countersign!(
					name: params[:signed_by_name],
					email: current_user.email,
					ip: request.remote_ip,
					user_agent: request.user_agent
				)
			else
				document.sign_as_employee!(
					name: params[:signed_by_name],
					email: current_user.email,
					ip: request.remote_ip,
					user_agent: request.user_agent,
					comments: params[:employee_comments],
					form_fields: sanitized_form_fields
				)
				AdminNotifier.staff_document_signed(document)
			end

			render json: document.reload.as_json
		rescue ArgumentError => e
			render json: { error: e.message }, status: :unprocessable_content
		end

		# Logged when the employee opens the document to read it.
		def view
			owned_document.record_view!(
				email: current_user.email,
				ip: request.remote_ip,
				user_agent: request.user_agent
			)
			head :ok
		end

		def pdf
			document = owned_document
			generator = StaffDocumentPdfGenerator.new(document)
			send_data generator.render,
			          filename: generator.filename,
			          type: 'application/pdf',
			          disposition: 'attachment'
		end

		private

		def require_staff!
			render json: { error: 'Forbidden' }, status: :forbidden unless current_user&.staff?
		end

		def require_admin!
			render json: { error: 'Forbidden' }, status: :forbidden unless current_user&.admin?
		end

		# Admins see every staff document; a teacher sees only their own. A
		# teacher with no linked teacher record sees nothing rather than
		# everything.
		def scoped_documents
			return StaffDocument.all if current_user.admin?

			StaffDocument.where(teacher_id: current_user.teacher&.id)
		end

		# Loads a document for an id action through the same scope, with a
		# redundant ownership re-check so a loosened scope in a future refactor
		# still cannot leak another employee's notice.
		def owned_document
			document = scoped_documents.find(params[:id])
			raise ActiveRecord::RecordNotFound if !current_user.admin? && document.teacher_id != current_user.teacher&.id

			document
		end

		# Flat key -> string/boolean pairs only, so arbitrary nested payloads
		# can't land in the record.
		def sanitized_form_fields
			raw = params[:form_fields]
			return {} unless raw.respond_to?(:to_unsafe_h)

			raw.to_unsafe_h.each_with_object({}) do |(key, value), clean|
				next unless key.to_s.match?(/\A[\w-]+\z/)

				clean[key.to_s] = value.in?([true, false, 'true', 'false']) ? ActiveModel::Type::Boolean.new.cast(value) : value.to_s
			end
		end
	end
end
