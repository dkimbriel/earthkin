# Renders an enrollment form (pending or signed) as a PDF. Layout lives in
# SignedDocumentPdf; this class supplies the enrollment-specific pieces.
class FormSignaturePdfGenerator < SignedDocumentPdf
  def initialize(signature)
    super()
    @signature = signature
    @body = signature.signed? ? signature.form_body_snapshot.to_s : signature.rendered_body
    @fields = signature.form_fields || {}
  end

  def filename
    child = @signature.child.full_name.parameterize
    "#{@signature.form_template.key.dasherize}-#{child}.pdf"
  end

  def body_text
    @body
  end

  def fields
    @fields
  end

  def subtitle
    "#{@signature.form_template.name}: #{@signature.child.full_name}"
  end

  def record_id
    @signature.id
  end

  def audit_entries
    @signature.audit_log || []
  end

  def certificate?
    @signature.signed?
  end

  def date_marker_value
    @signature.signed_at
  end

  def signature_block(doc)
    doc.move_down 10
    doc.stroke_horizontal_rule
    doc.move_down 8
    if @signature.signed?
      draw_signature(doc, @signature.signed_by_name,
                     "Signed by #{@signature.signed_by_name} (#{@signature.signed_by_email}) on #{@signature.signed_at.strftime('%B %-d, %Y at %I:%M %p %Z')}")
    else
      draw_blank_signature_line(doc, 'Parent/Guardian signature (sign in the parent portal)')
    end
    doc.move_down 8
  end
end
