class ProgramClassTeacher < ApplicationRecord
  belongs_to :program_class
  belongs_to :teacher
end
