class ProgramTeacher < ApplicationRecord
  belongs_to :program
  belongs_to :teacher
end
