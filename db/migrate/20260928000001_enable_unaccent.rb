class EnableUnaccent < ActiveRecord::Migration[7.0]
	def change
		# List search (Searchable) matches "Jose" to "José", so it compares
		# unaccent(column) to unaccent(query).
		enable_extension 'unaccent'
	end
end
