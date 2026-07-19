# frozen_string_literal: true

module Api
	class ContentItemsController < BaseController
		before_action :require_admin!, except: [:index]
		before_action :set_content_item, only: [:update, :destroy]

		def index
			items = ContentItem.visible_to(current_user).includes(:teachers).order(:category, :title)
			render json: items.as_json
		end

		def create
			item = ContentItem.create!(content_item_params)
			assign_teachers(item)
			render json: item.as_json, status: :created
		end

		def update
			@content_item.update!(content_item_params)
			assign_teachers(@content_item)
			render json: @content_item.reload.as_json
		end

		def destroy
			@content_item.soft_delete!
			head :no_content
		end

		private

		def set_content_item
			@content_item = ContentItem.find(params[:id])
		end

		def content_item_params
			params.require(:content_item).permit(:title, :url, :description, :category, :visibility, :visible_to_families)
		end

		def assign_teachers(item)
			return unless params[:content_item].key?(:teacher_ids)

			teacher_ids = item.visibility == 'specific_teachers' ? Array(params[:content_item][:teacher_ids]).reject(&:blank?) : []
			item.teacher_ids = teacher_ids
		end
	end
end
