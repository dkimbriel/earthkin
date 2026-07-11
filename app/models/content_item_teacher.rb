class ContentItemTeacher < ApplicationRecord
  belongs_to :content_item
  belongs_to :teacher
end
