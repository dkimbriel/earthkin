# Skeletons for staff documents. These are structure only: the specific facts
# of any one notice (dates, incidents, final pay) are typed into the body when
# an admin issues the document, so no personnel detail lives in the codebase.
class StaffDocumentTemplates
  TERMINATION_LETTER = <<~BODY.freeze
    # {{school_name}}
    ## Employee Notice

    **Employee Name:** {{employee_name}}
    **Position:** {{employee_position}}
    **Date of Notice:** {{current_date}}
    **Issued By:** {{issued_by}}, {{issued_by_title}}
    **Type of Action:** (Termination of employment, effective date)

    ## Purpose of This Notice
    (State the decision and its effective date, and summarize the reason in one or two sentences.)

    ## Relevant Job Expectations
    (List the responsibilities from the job description or offer letter that this notice concerns.)

    ## Description of the Concern
    (Give the specific, dated examples the decision rests on.)

    ## Impact
    (Describe the effect on the team, families, and the school.)

    ## Basis for Termination
    (Tie the examples together into the reason for the decision.)

    ## Next Steps
    (Last day of employment, final paycheck, remaining benefits, return of property, references.)

    ## Acknowledgment
    Your signature below indicates that you have received and read this notice. It does not
    necessarily indicate agreement with its contents. You are encouraged to add written comments
    below if you wish.

    [[signature]]

    {{employee_name}}, {{employee_position}}

    Date: [[date]]

    {{issued_by}}, {{issued_by_title}}

    Date:

    ## Employee Comments (optional):
  BODY

  BODIES = {
    'termination_letter' => TERMINATION_LETTER
  }.freeze

  def self.body_for(key)
    BODIES.fetch(key, "(Document text not set yet. An admin can edit this under Emails → Staff Documents.)")
  end
end
