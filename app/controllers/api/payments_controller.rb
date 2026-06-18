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
			payment.destroy!
			head :no_content
		end

		def send_invoice
			payment = Payment.find(params[:id])
			if payment.status == 'completed'
				PaymentMailer.receipt(payment.id).deliver_later
				render json: { message: 'Receipt email sent successfully' }
			else
				PaymentMailer.invoice(payment.id).deliver_later
				render json: { message: 'Invoice email sent successfully' }
			end
		end

		private

		def payment_params
			params.require(:payment).permit(:program_enrollment_id, :amount, :payment_method, :payment_date, :status, :notes)
		end
	end
end
