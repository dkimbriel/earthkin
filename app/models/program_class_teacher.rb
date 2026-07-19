class ProgramClassTeacher < ApplicationRecord
  include SoftDeletable

  belongs_to :program_class
  belongs_to :teacher
end
