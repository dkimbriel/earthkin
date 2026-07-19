class ProgramTeacher < ApplicationRecord
  include SoftDeletable

  belongs_to :program
  belongs_to :teacher
end
