# frozen_string_literal: true

module Api
	class PaymentsController < BaseController
		def index
			payments = Payment.includes(program_enrollment: %i[child program]).order(payment_date: :desc)
			payments = payments.where(program_enrollment_id: params[:program_enrollment_id]) if params[:program_enrollment_id]
			render json: payments.as_json(include: { program_enrollment: { include: %i[child program] } })
		end

		def show
			payment = Payment.includes(program_enrollment: %i[child program]).find(params[:id])
			render json: payment.as_json(include: { program_enrollment: { include: %i[child program] } })
		end

		def create
			payment = Payment.create!(payment_params)
			render json: payment.as_json(include: { program_enrollment: { include: %i[child program] } }), status: :created
		end

		def destroy
			payment = Payment.find(params[:id])
			payment.soft_delete!
			head :no_content
		end

		def send_invoice
			payment = Payment.find(params[:id])
			email_type = payment.status == 'completed' ? 'receipt' : 'invoice'
			email = EmailTrackingService.new(payment).send_email('PaymentMailer', email_type, [payment.id])

			if email.status == 'sent'
				render json: { message: "#{email_type.titleize} email sent successfully" }
			else
				render json: { error: "#{email_type.titleize} email failed to send: #{email.error_message}" }, status: :unprocessable_entity
			end
		end

		private

		def payment_params
			params.require(:payment).permit(:program_enrollment_id, :amount, :payment_method, :payment_date, :status, :notes)
		end
	end
end
