require 'rails_helper'

RSpec.describe EmailTemplate, type: :model do
  describe '#rendered_html' do
    it 'inserts trusted (html_safe) token values as-is so date options render as buttons' do
      template = EmailTemplate.new(body: "Please click the date that works best:\n{{date_options}}")
      buttons = '<a href="https://portal.test/meetings/tok/confirm?date=1">Wednesday, July 22 at 08:00 AM</a>'.html_safe

      html = template.rendered_html(date_options: buttons)

      expect(html).to include('<a href="https://portal.test/meetings/tok/confirm?date=1">')
      expect(html).to include('Wednesday, July 22 at 08:00 AM</a>')
      expect(html).not_to include('&lt;a href') # not escaped into visible text
    end

    it 'escapes and auto-links ordinary string token values' do
      template = EmailTemplate.new(body: 'Visit {{link}}')

      html = template.rendered_html(link: 'https://x.test/page')

      expect(html).to include('<a href="https://x.test/page">https://x.test/page</a>')
    end

    it 'escapes HTML in untrusted values' do
      template = EmailTemplate.new(body: '{{name}}')

      html = template.rendered_html(name: '<script>alert(1)</script>')

      expect(html).to include('&lt;script&gt;')
      expect(html).not_to include('<script>')
    end
  end

  describe '#rendered_text' do
    it 'flattens trusted button HTML back to plain "label — url" lines for the composer' do
      template = EmailTemplate.new(body: "Pick a date:\n{{date_options}}")
      buttons = (
        '<a href="https://portal.test/confirm?date=1">Mon, July 20</a><br>' \
        '<a href="https://portal.test/confirm?date=2">Tue, July 21</a>'
      ).html_safe

      text = template.rendered_text(date_options: buttons)

      expect(text).to include('Mon, July 20 — https://portal.test/confirm?date=1')
      expect(text).to include('Tue, July 21 — https://portal.test/confirm?date=2')
      expect(text).not_to include('<a ')
    end
  end
end
