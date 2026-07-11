# Renders an enrollment form (pending or signed) as a PDF: the structured
# document with filled-in fields, the cursive-style signature, and — for
# signed forms — a signing certificate page with the full audit trail.
class FormSignaturePdfGenerator
  FIELD_RE = /\[\[(text|textarea|checkbox|signature|date)(?::([\w-]+))?(?:\|([^\]]*))?\]\]/
  HEADING_SIZES = { 1 => 18, 2 => 14, 3 => 12 }.freeze

  def initialize(signature)
    @signature = signature
    @body = signature.signed? ? signature.form_body_snapshot.to_s : signature.form_template.body.to_s
    @fields = signature.form_fields || {}
  end

  def render
    doc = Prawn::Document.new(page_size: 'LETTER', margin: 54)
    doc.font 'Times-Roman'
    doc.font_size 10.5

    header(doc)
    @body.split("\n").each { |line| render_line(doc, line.rstrip) }
    certificate(doc) if @signature.signed?

    doc.render
  end

  def filename
    child = @signature.child.full_name.parameterize
    "#{@signature.form_template.key.dasherize}-#{child}.pdf"
  end

  private

  def header(doc)
    doc.text safe('Earthkin Nature School'), size: 9, color: '2e7d32'
    doc.text safe("#{@signature.form_template.name} — #{@signature.child.full_name}"), size: 9, color: '666666'
    doc.stroke_horizontal_rule
    doc.move_down 12
  end

  def render_line(doc, line)
    if line.strip.empty?
      doc.move_down 6
    elsif (heading = line.match(/^(#{Regexp.escape('#')}{1,3})\s+(.*)$/))
      doc.move_down heading[1].length == 3 ? 6 : 10
      doc.text inline(heading[2]), size: HEADING_SIZES[heading[1].length], style: :bold, inline_format: true
      doc.move_down 4
    elsif line =~ /\[\[signature\]\]/
      signature_block(doc)
    elsif (textarea = line.match(/^\[\[textarea:([\w-]+)(?:\|([^\]]*))?\]\]$/))
      value = @fields[textarea[1]].to_s
      doc.text inline("#{textarea[2] || textarea[1]}:"), inline_format: true, color: '555555', size: 9
      doc.text safe(value.presence || '(not provided)'), style: value.present? ? :normal : :italic
      doc.move_down 4
    elsif (bullet = line.match(/^-\s+(.*)$/))
      doc.indent(14) { doc.text inline("• #{bullet[1]}"), inline_format: true }
    elsif (numbered = line.match(/^(\d+\.)\s+(.*)$/))
      doc.indent(14) { doc.text inline("#{numbered[1]} #{numbered[2]}"), inline_format: true }
    else
      doc.text inline(line), inline_format: true
    end
  end

  def signature_block(doc)
    doc.move_down 10
    doc.stroke_horizontal_rule
    doc.move_down 8
    if @signature.signed?
      doc.font('Times-Italic') do
        doc.text safe(@signature.signed_by_name.to_s), size: 26
      end
      doc.text safe("Signed by #{@signature.signed_by_name} (#{@signature.signed_by_email}) on #{@signature.signed_at.strftime('%B %-d, %Y at %I:%M %p %Z')}"), size: 9, color: '555555'
    else
      doc.move_down 14
      doc.text 'X ____________________________________', size: 12
      doc.text 'Parent/Guardian signature (sign in the parent portal)', size: 9, color: '555555'
    end
    doc.move_down 8
  end

  def certificate(doc)
    doc.start_new_page
    doc.text 'Signing Certificate', size: 18, style: :bold
    doc.move_down 4
    doc.text safe("#{@signature.form_template.name} — #{@signature.child.full_name}"), size: 11
    doc.text "Record ID: #{@signature.id}", size: 9, color: '555555'
    doc.move_down 12

    doc.text 'Event History', size: 12, style: :bold
    doc.move_down 4
    (@signature.audit_log || []).each do |entry|
      time = begin
        Time.zone.parse(entry['at']).strftime('%B %-d, %Y at %I:%M:%S %p %Z')
      rescue StandardError
        entry['at']
      end
      doc.text safe("#{entry['event'].to_s.upcase} — #{time}"), size: 10, style: :bold
      details = []
      details << "By: #{entry['by']}" if entry['by'].present?
      details << "Email: #{entry['email']}" if entry['email'].present?
      details << "IP: #{entry['ip']}" if entry['ip'].present?
      details << "Device: #{entry['user_agent'].to_s.truncate(90)}" if entry['user_agent'].present?
      details.each { |d| doc.indent(14) { doc.text safe(d), size: 9, color: '555555' } }
      if entry['document_sha256'].present?
        doc.indent(14) { doc.text "Document fingerprint (SHA-256): #{entry['document_sha256']}", size: 8, color: '555555' }
      end
      doc.move_down 6
    end

    doc.move_down 8
    doc.text 'This certificate records the electronic signing of the document above. The document fingerprint is a SHA-256 hash of the exact text presented at signing.', size: 8, color: '777777'
  end

  # Substitute field markers with their values and convert **bold** to
  # Prawn inline format, escaping markup characters first.
  def inline(text)
    substituted = text.gsub(FIELD_RE) do
      type = Regexp.last_match(1)
      key = Regexp.last_match(2)
      label = Regexp.last_match(3) || key
      case type
      when 'checkbox'
        "#{@fields[key] ? '[X]' : '[  ]'} #{label}"
      when 'date'
        @signature.signed_at ? @signature.signed_at.strftime('%m/%d/%Y') : '__________'
      else
        value = @fields[key].to_s
        value.present? ? value : '______________________'
      end
    end
    escaped = safe(substituted).gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')
    escaped.gsub(/\*\*(.+?)\*\*/, '<b>\1</b>')
  end

  # Prawn's built-in fonts only support Windows-1252; replace anything else.
  def safe(text)
    text.to_s.encode('Windows-1252', invalid: :replace, undef: :replace, replace: '?')
        .encode('UTF-8')
  end
end
