class ContentItemTeacher < ApplicationRecord
  include SoftDeletable

  belongs_to :content_item
  belongs_to :teacher
end
