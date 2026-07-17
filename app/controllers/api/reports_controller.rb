# frozen_string_literal: true

module Api
	class ReportsController < BaseController
		def weekly_revenue
			# Get all program classes with their program's revenue data
			classes = ProgramClass.includes(program: :program_enrollments)
			                      .where(date: 12.weeks.ago.to_date..12.weeks.from_now.to_date)
			                      .order(:date)

			# Group by week (Monday start)
			weekly_data = classes.group_by { |pc| pc.date.beginning_of_week(:monday) }
			                    .map do |week_start, week_classes|
				revenue = week_classes.sum { |pc| pc.program.revenue_per_class.to_f }
				{
					week_start: week_start,
					week_end: week_start + 6.days,
					class_count: week_classes.count,
					revenue: revenue,
					classes: week_classes.map do |pc|
						{
							id: pc.id,
							name: pc.name,
							date: pc.date,
							program_name: pc.program.name,
							program_id: pc.program.id,
							revenue: pc.program.revenue_per_class.to_f
						}
					end
				}
			end

			render json: weekly_data
		end
	end
end
