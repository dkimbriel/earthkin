# Server-side search for the admin list pages. A model declares the columns
# it searches, optionally across associations:
#
#   searchable 'families.name', 'parents.first_name', 'children.first_name',
#              joins: %i[parents children]
#
# Model.search(query) keeps records where every word of the query matches at
# least one of those columns, in any order and on any joined row, ignoring
# case and accents ("jose smi" finds "José Smith"). Each word becomes an
# `id IN (subquery)`, so the joins never duplicate rows or disturb the outer
# scope's order and includes. A blank query returns the scope unchanged.
module Searchable
  extend ActiveSupport::Concern

  class_methods do
    def searchable(*columns, joins: nil)
      @search_columns = columns
      @search_joins = joins
    end

    def search(query)
      words = query.to_s.split
      return all if words.empty?

      words.reduce(all) { |scope, word| scope.where(id: ids_matching(word)) }
    end

    private

    def ids_matching(word)
      raise ArgumentError, "#{name} has no searchable columns" if @search_columns.blank?

      condition = @search_columns
                  .map { |column| "unaccent(COALESCE(#{column}::text, '')) ILIKE unaccent(:pattern)" }
                  .join(' OR ')
      # unscoped: the outer scope already applies soft-delete and any filters.
      base = unscoped
      base = base.left_joins(@search_joins) if @search_joins
      base.where(condition, pattern: "%#{sanitize_sql_like(word)}%").select(arel_table[:id])
    end
  end
end
