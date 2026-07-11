class EmailTemplate < ApplicationRecord
  # Workflow emails that can be overridden, with the placeholders each supports.
  KNOWN_KEYS = {
    'enrollment_invite' => %w[parent_name program_name enrollment_link],
    'meeting_scheduled' => %w[parent_name child_name program_name meeting_datetime location_name],
    'enrollment_fee_request' => %w[parent_name child_name enrollment_fee payment_link location_name],
    'enrollment_forms' => %w[parent_name child_name program_name],
    'enrollment_confirmed' => %w[child_name program_name],
    'welcome_email' => %w[parent_name email password login_url],
    'application_status_update' => %w[parent_name status login_url]
  }.freeze

  validates :name, :subject, :body, presence: true
  validates :key, uniqueness: true, inclusion: { in: KNOWN_KEYS.keys }, allow_nil: true

  def self.for(key)
    find_by(key: key)
  end

  def rendered_subject(vars = {})
    interpolate(subject, vars)
  end

  # Plain text body -> simple HTML: {{placeholders}} substituted (URLs become
  # links), blank lines split paragraphs.
  def rendered_html(vars = {})
    escaped = ERB::Util.html_escape(body)
    substituted = escaped.gsub(/{{\s*(\w+)\s*}}/) do
      value = vars[Regexp.last_match(1).to_sym] || vars[Regexp.last_match(1)]
      value = value.to_s
      if value.start_with?('http://', 'https://')
        %(<a href="#{ERB::Util.html_escape(value)}">#{ERB::Util.html_escape(value)}</a>)
      else
        ERB::Util.html_escape(value)
      end
    end
    substituted.split(/\r?\n\r?\n+/).map { |para| "<p>#{para.gsub(/\r?\n/, '<br>')}</p>" }.join("\n")
  end

  private

  def interpolate(text, vars)
    text.gsub(/{{\s*(\w+)\s*}}/) do
      (vars[Regexp.last_match(1).to_sym] || vars[Regexp.last_match(1)]).to_s
    end
  end
end
