# frozen_string_literal: true

module Api
	module Admin
		# Backs the "Recently Deleted" admin page: lists soft-deleted records the
		# admin deleted directly (not cascade children) and restores them.
		class DeletedRecordsController < Api::BaseController
			before_action :require_admin!

			# Models that have a delete button in the UI and can be restored.
			RESTORABLE = {
				'Family' => Family,
				'Parent' => Parent,
				'Child' => Child,
				'Program' => Program,
				'ProgramClass' => ProgramClass,
				'ProgramEnrollment' => ProgramEnrollment,
				'PaymentPlan' => PaymentPlan,
				'Payment' => Payment,
				'Teacher' => Teacher,
				'Location' => Location,
				'ContentItem' => ContentItem,
				'User' => User,
				'EmailTemplate' => EmailTemplate,
				'Email' => Email
			}.freeze

			# GET /api/admin/deleted_records
			def index
				records = RESTORABLE.flat_map do |type, klass|
					klass.only_deleted.order(deleted_at: :desc).limit(100).filter_map do |record|
						next unless record.deletion_root?

						{
							type: type,
							type_label: klass.model_name.human,
							id: record.id,
							label: record.deleted_label,
							deleted_at: record.deleted_at
						}
					end
				end

				render json: records.sort_by { |r| r[:deleted_at] }.reverse
			end

			# POST /api/admin/deleted_records/restore  { type:, id: }
			def restore
				klass = RESTORABLE[params[:type]]
				return render json: { error: 'Unknown record type' }, status: :unprocessable_content if klass.nil?

				record = klass.with_deleted.find(params[:id])
				record.restore!
				render json: { message: "Restored #{record.deleted_label}" }
			rescue ActiveRecord::RecordNotUnique => e
				render json: {
					error: 'Could not restore: a live record now conflicts with this one (e.g. the same email is in use).'
				}, status: :unprocessable_content
			end
		end
	end
end
