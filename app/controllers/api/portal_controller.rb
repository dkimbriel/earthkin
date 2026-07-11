# frozen_string_literal: true

module Api
	# Parent-facing portal endpoints. Everything is scoped to the logged-in
	# parent's family — parents never see other families' data.
	class PortalController < ApplicationController
		before_action :authenticate_user!
		before_action :require_parent!

		rescue_from ActiveRecord::RecordNotFound, with: -> { render json: { error: 'Record not found' }, status: :not_found }

		def overview
			children = family.children.includes(program_enrollments: [:program, :enrollment_payment_plan, :payment_plan])

			render json: {
				family: { id: family.id, name: family.name },
				parents: family.parents.map { |p| { id: p.id, name: p.full_name, email: p.email } },
				children: children.map do |child|
					{
						id: child.id,
						name: child.full_name,
						enrollments: child.program_enrollments.map { |e| enrollment_json(e) }
					}
				end
			}
		end

		def events
			enrolled_program_ids = family_enrollments.where(status: %w[pending confirmed]).select(:program_id)
			classes = ProgramClass.where(program_id: enrolled_program_ids).where.not(date: nil).includes(:program)
			school_events = Event.published.where(status: %w[scheduled confirmed]).where.not(scheduled_at: nil).includes(:location)

			render json: {
				classes: classes.map do |c|
					{ id: c.id, title: "#{c.program.name}: #{c.name}", date: c.date }
				end,
				events: school_events.map do |e|
					{
						id: e.id,
						title: e.title,
						event_type: e.event_type,
						scheduled_at: e.scheduled_at,
						description: e.description,
						location: e.location&.name
					}
				end
			}
		end

		def payments
			enrollments = family_enrollments.includes(:child, :program, :enrollment_payment_plan, :payment_plan, :payments)

			render json: enrollments.map { |e|
				plan = e.enrollment_payment_plan
				{
					enrollment_id: e.id,
					child_name: e.child.full_name,
					program_name: e.program.name,
					total_owed: e.total_owed,
					total_paid: e.total_paid,
					balance_due: e.balance_due,
					plan: plan && {
						name: e.payment_plan&.name,
						enrollment_fee: plan.enrollment_fee,
						enrollment_fee_paid: plan.enrollment_fee_paid,
						installments: plan.installments
					},
					payments: e.payments.sort_by(&:payment_date).reverse.map do |p|
						{
							id: p.id,
							amount: p.amount,
							payment_date: p.payment_date,
							status: p.status,
							payment_type: p.payment_type,
							payment_method: p.payment_method
						}
					end
				}
			}
		end

		private

		def require_parent!
			unless current_user&.parent_role? && current_user.parent
				render json: { error: 'Forbidden' }, status: :forbidden
			end
		end

		def family
			@family ||= current_user.parent.family
		end

		def family_enrollments
			ProgramEnrollment.where(child_id: family.children.select(:id))
		end

		def enrollment_json(enrollment)
			{
				id: enrollment.id,
				program_name: enrollment.program.name,
				program_start_date: enrollment.program.start_date,
				status: enrollment.status,
				workflow_status: enrollment.workflow_status,
				payment_plan_name: enrollment.payment_plan&.name
			}
		end
	end
end
