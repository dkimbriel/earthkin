# frozen_string_literal: true

module Api
	class EmailsController < BaseController
		before_action :require_admin!
		before_action :set_email, only: [:update, :destroy, :deliver]

		def index
			emails = Email.recent.includes(:emailable)
			emails = emails.where(status: params[:status]) if params[:status].present?
			render json: emails.limit(200).map { |e| email_json(e) }
		end

		# Create a manual email draft.
		def create
			parent = params.dig(:email, :parent_id).presence && Parent.find(params[:email][:parent_id])

			email = Email.create!(
				emailable: parent,
				mailer_class: 'ManualMailer',
				email_type: 'manual',
				status: 'draft',
				recipient: params.dig(:email, :recipient).presence || parent&.email,
				subject: params.dig(:email, :subject),
				html_body: render_body(params.dig(:email, :body)),
				metadata: { 'body' => params.dig(:email, :body).to_s }
			)

			render json: email_json(email), status: :created
		end

		def update
			return render json: { error: 'Only drafts can be edited' }, status: :unprocessable_content unless @email.draft?

			@email.update!(
				recipient: params.dig(:email, :recipient).presence || @email.recipient,
				subject: params.dig(:email, :subject).presence || @email.subject,
				html_body: render_body(params.dig(:email, :body)),
				metadata: @email.metadata.merge('body' => params.dig(:email, :body).to_s)
			)

			render json: email_json(@email)
		end

		# Send a draft.
		def deliver
			return render json: { error: 'Only drafts can be sent' }, status: :unprocessable_content unless @email.draft?

			begin
				ManualMailer.compose(@email.id).deliver_now
				@email.mark_sent!
				render json: email_json(@email.reload)
			rescue StandardError => e
				@email.mark_failed!(e)
				render json: { error: "Failed to send: #{e.message}" }, status: :unprocessable_content
			end
		end

		def destroy
			return render json: { error: 'Only drafts can be deleted' }, status: :unprocessable_content unless @email.draft?

			@email.destroy!
			head :no_content
		end

		private

		def set_email
			@email = Email.find(params[:id])
		end

		def render_body(body)
			text = body.to_s
			escaped = ERB::Util.html_escape(text)
			escaped.split(/\r?\n\r?\n+/).map { |para| "<p>#{para.gsub(/\r?\n/, '<br>')}</p>" }.join("\n")
		end

		def email_json(email)
			{
				id: email.id,
				recipient: email.recipient,
				subject: email.subject,
				status: email.status,
				email_type: email.email_type,
				mailer_class: email.mailer_class,
				body: email.metadata['body'],
				html_body: email.html_body,
				error_message: email.error_message,
				sent_at: email.sent_at,
				created_at: email.created_at
			}
		end
	end
end
