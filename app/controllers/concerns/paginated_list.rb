# frozen_string_literal: true

# Shared index rendering for the admin list pages: search (?q=, see
# Searchable) and pagination (?page=, ?per_page=).
#
#   render_list(Family.includes(:parents).order(:name)) { |f| f.as_json(include: :parents) }
#
# With ?page= it responds { data: [...], meta: { page, per_page, total, total_pages } }.
# Without it, it returns the plain array as before, so pickers and badges that
# need every record keep working.
module PaginatedList
	DEFAULT_PER_PAGE = 25
	MAX_PER_PAGE = 100

	private

	def render_list(scope, &serialize)
		serialize ||= :as_json.to_proc
		scope = scope.search(params[:q]) if params[:q].present?
		return render(json: scope.map(&serialize)) if params[:page].blank?

		per_page = params[:per_page].to_i
		per_page = DEFAULT_PER_PAGE unless per_page.positive?
		per_page = [per_page, MAX_PER_PAGE].min

		total = scope.count
		total_pages = [(total / per_page.to_f).ceil, 1].max
		page = params[:page].to_i.clamp(1, total_pages)
		records = scope.offset((page - 1) * per_page).limit(per_page)

		render json: {
			data: records.map(&serialize),
			meta: { page: page, per_page: per_page, total: total, total_pages: total_pages }
		}
	end
end
