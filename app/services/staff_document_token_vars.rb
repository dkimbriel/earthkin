# Builds the {{token}} values for staff document templates. Used when an admin
# issues a document, at which point the resolved text is copied onto the record
# and the tokens are never re-evaluated.
class StaffDocumentTokenVars
  def self.for(document)
    new(document).build
  end

  def initialize(document)
    @document = document
    @teacher = document.teacher
  end

  def build
    {
      employee_name: @teacher&.full_name,
      employee_position: @document.employee_position,
      employee_email: @teacher&.email,
      school_name: ENV.fetch('SCHOOL_NAME', 'Earthkin Nature School'),
      current_date: Date.current.strftime('%B %-d, %Y'),
      issued_by: @document.issued_by&.display_name,
      issued_by_title: ENV.fetch('SCHOOL_DIRECTOR_TITLE', 'Executive Director')
    }
  end
end
