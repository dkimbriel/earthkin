# Shared rendering for every signable document we produce as a PDF: the
# structured body with filled-in fields, the cursive-style signature, and, once
# signed, a signing certificate page carrying the full audit trail.
#
# Subclasses supply the document-specific parts (what text to render, who signs
# it, what the header says). Everything about how a page is laid out lives here
# so enrollment forms and staff documents cannot drift apart.
class SignedDocumentPdf
  FIELD_RE = /\[\[(text|textarea|checkbox|signature|date)(?::([\w-]+))?(?:\|([^\]]*))?\]\]/
  HEADING_SIZES = { 1 => 18, 2 => 14, 3 => 12 }.freeze
  LOGO_PATH = Rails.root.join('public/logo-green.png')

  def render
    doc = Prawn::Document.new(page_size: 'LETTER', margin: 54)
    doc.font 'Times-Roman'
    doc.font_size 10.5

    header(doc)
    body_text.split("\n").each { |line| render_line(doc, line.rstrip) }
    signature_footer(doc)
    certificate(doc) if certificate?

    doc.render
  end

  # Subclass responsibilities.
  def filename
    raise NotImplementedError
  end

  def body_text
    raise NotImplementedError
  end

  def subtitle
    raise NotImplementedError
  end

  def record_id
    raise NotImplementedError
  end

  def fields
    {}
  end

  def audit_entries
    []
  end

  def certificate?
    false
  end

  # The date a [[date]] marker resolves to, or nil to leave it blank.
  def date_marker_value
    nil
  end

  # Rendered where a [[signature]] marker appears in the body.
  def signature_block(doc); end

  # Rendered after the body, for documents with a second signer.
  def signature_footer(doc); end

  private

  def header(doc)
    if File.exist?(LOGO_PATH)
      doc.image LOGO_PATH.to_s, fit: [150, 56], position: :left
      doc.move_down 4
    else
      doc.text safe('Earthkin Nature School'), size: 12, style: :bold, color: '2e7d32'
    end
    doc.text safe(subtitle), size: 9, color: '666666'
    doc.move_down 4
    doc.stroke_color '2e7d32'
    doc.stroke_horizontal_rule
    doc.stroke_color '000000'
    doc.move_down 14
  end

  def render_line(doc, line)
    line = line.gsub(/\[\[(?:require-one:[\w,-]+(?:\|[^\]]*)?|waive-required-if:[\w-]+)\]\]/, '').rstrip
    if line.strip.empty?
      doc.move_down 6
    elsif (heading = line.match(/^(#{Regexp.escape('#')}{1,3})\s+(.*)$/))
      doc.move_down heading[1].length == 3 ? 6 : 10
      doc.text inline(heading[2]), size: HEADING_SIZES[heading[1].length], style: :bold, inline_format: true
      doc.move_down 4
    elsif line =~ /\[\[signature\]\]/
      signature_block(doc)
    elsif (textarea = line.match(/^\[\[textarea:([\w-]+)(?:\|([^\]]*))?\]\]$/))
      value = fields[textarea[1]].to_s
      doc.text inline("#{(textarea[2] || textarea[1]).delete_suffix('*')}:"), inline_format: true, color: '555555', size: 9
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

  # A signed name in cursive over the attribution line, used by both signers.
  def draw_signature(doc, name, attribution)
    doc.font('Times-Italic') do
      doc.text safe(name.to_s), size: 26
    end
    doc.text safe(attribution), size: 9, color: '555555'
  end

  def draw_blank_signature_line(doc, label)
    doc.move_down 14
    doc.text 'X ____________________________________', size: 12
    doc.text safe(label), size: 9, color: '555555'
  end

  def certificate(doc)
    doc.start_new_page
    doc.image LOGO_PATH.to_s, fit: [120, 45], position: :left if File.exist?(LOGO_PATH)
    doc.move_down 6
    doc.text 'Signing Certificate', size: 18, style: :bold
    doc.move_down 4
    doc.text safe(subtitle), size: 11
    doc.text "Record ID: #{record_id}", size: 9, color: '555555'
    doc.move_down 12

    doc.text 'Event History', size: 12, style: :bold
    doc.move_down 4
    audit_entries.each { |entry| certificate_entry(doc, entry) }

    doc.move_down 8
    doc.text 'This certificate records the electronic signing of the document above. The document fingerprint is a SHA-256 hash of the exact text presented at signing.', size: 8, color: '777777'
  end

  def certificate_entry(doc, entry)
    time = begin
      Time.zone.parse(entry['at']).strftime('%B %-d, %Y at %I:%M:%S %p %Z')
    rescue StandardError
      entry['at']
    end
    doc.text safe("#{entry['event'].to_s.tr('_', ' ').upcase}: #{time}"), size: 10, style: :bold
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

  # Substitute field markers with their values and convert **bold** to
  # Prawn inline format, escaping markup characters first.
  def inline(text)
    substituted = text.gsub(FIELD_RE) do
      type = Regexp.last_match(1)
      key = Regexp.last_match(2)
      label = Regexp.last_match(3) || key
      case type
      when 'checkbox'
        "#{fields[key] ? '[X]' : '[  ]'} #{label}"
      when 'date'
        date_marker_value ? date_marker_value.strftime('%m/%d/%Y') : '__________'
      else
        value = fields[key].to_s
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
