# Renders a staff document (warning, performance notice, termination letter)
# as a PDF: the notice, the employee's acknowledgment and any written comments
# they attached, and the director's counter-signature.
class StaffDocumentPdfGenerator < SignedDocumentPdf
  def initialize(document)
    super()
    @document = document
  end

  def filename
    employee = @document.teacher.full_name.parameterize
    "#{@document.title.parameterize}-#{employee}.pdf"
  end

  def body_text
    @document.signing_text
  end

  def fields
    @document.form_fields || {}
  end

  def subtitle
    "#{@document.title}: #{@document.teacher.full_name}"
  end

  def record_id
    @document.id
  end

  def audit_entries
    @document.audit_log || []
  end

  # Any signature at all is worth certifying: a notice acknowledged but not yet
  # counter-signed still needs its audit trail on paper.
  def certificate?
    @document.employee_signed? || @document.director_signed?
  end

  def date_marker_value
    @document.employee_signed_at
  end

  # The employee's acknowledgment, rendered where [[signature]] appears.
  def signature_block(doc)
    doc.move_down 10
    doc.stroke_horizontal_rule
    doc.move_down 8
    if @document.employee_signed?
      draw_signature(doc, @document.employee_signed_by_name, employee_attribution)
    else
      draw_blank_signature_line(doc, "#{employee_label} (sign in the portal)")
    end
    doc.move_down 8
  end

  # Written comments and the counter-signature always close the document,
  # whether or not the body carries a [[signature]] marker.
  def signature_footer(doc)
    comments_block(doc)
    countersignature_block(doc)
  end

  private

  def employee_label
    [@document.teacher.full_name, @document.employee_position.presence].compact.join(', ')
  end

  def employee_attribution
    signed = @document.employee_signed_at.strftime('%B %-d, %Y at %I:%M %p %Z')
    email = @document.employee_signed_by_email.presence
    who = email ? "#{@document.employee_signed_by_name} (#{email})" : @document.employee_signed_by_name
    "Acknowledged by #{who} on #{signed}. A signature records receipt of this notice, not agreement with it."
  end

  def comments_block(doc)
    doc.move_down 12
    # Most notices end with their own "Employee Comments" heading, carried over
    # from the letter itself. Only add one when the document lacks it.
    unless body_text.match?(/employee comments/i)
      doc.text 'Employee Comments', size: 12, style: :bold
      doc.move_down 4
    end
    comments = @document.employee_comments.to_s
    doc.text safe(comments.presence || '(none provided)'),
             style: comments.present? ? :normal : :italic
  end

  def countersignature_block(doc)
    doc.move_down 16
    doc.stroke_horizontal_rule
    doc.move_down 8
    if @document.director_signed?
      draw_signature(doc, @document.director_signed_by_name,
                     "Counter-signed by #{@document.director_signed_by_name} on #{@document.director_signed_at.strftime('%B %-d, %Y at %I:%M %p %Z')}")
    else
      draw_blank_signature_line(doc, "#{ENV.fetch('SCHOOL_DIRECTOR_TITLE', 'Executive Director')} (counter-signature pending)")
    end
  end
end
