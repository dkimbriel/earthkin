# Builds the {{token}} values for enrollment form templates. Used by
# EnrollmentFormSignature#rendered_body when presenting a form to a family
# and when snapshotting the signed text.
class FormTokenVars
  def self.for(signature)
    new(signature).build
  end

  def initialize(signature)
    @signature = signature
    @child = signature.child
    @application = signature.enrollment_application
    @program = signature.enrollment&.program || @application&.program
  end

  def build
    {
      child_name: @child&.full_name,
      parent_name: parent_name,
      parent2_name: parent2_name,
      program_name: @program&.name,
      school_name: ENV.fetch('SCHOOL_NAME', 'Earthkin Nature School'),
      school_year: school_year,
      current_date: Date.current.strftime('%B %-d, %Y')
    }
  end

  private

  def parent_name
    return @application.full_parent_name if @application&.parent_first_name.present?

    @child&.family&.parents&.first&.full_name
  end

  def parent2_name
    return '' unless @application&.parent2_first_name.present?

    "#{@application.parent2_first_name} #{@application.parent2_last_name}".strip
  end

  def school_year
    return '' unless @program&.start_date

    start_year = @program.start_date.year
    end_year = @program.end_date&.year || start_year
    end_year > start_year ? "#{start_year}–#{end_year}" : start_year.to_s
  end
end
