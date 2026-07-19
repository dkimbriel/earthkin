class EmailTemplate < ApplicationRecord
  include SoftDeletable

  # Workflow emails that can be edited, with the placeholders each supports.
  KNOWN_KEYS = {
    'enrollment_invite' => %w[parent_name program_name program_dates class_days time_range tuition enrollment_fee enrollment_link],
    'meeting_invite' => %w[parent_name child_name program_name program_dates class_days time_range tuition enrollment_fee location_name date_options],
    'meeting_scheduled' => %w[parent_name child_name program_name meeting_datetime location_name location_address handbook_url],
    'enrollment_fee_request' => %w[parent_name child_name enrollment_fee payment_link location_name handbook_url],
    'enrollment_forms' => %w[parent_name child_name program_name login_url],
    'enrollment_confirmed' => %w[child_name program_name program_dates class_days payment_plan_summary],
    'welcome_email' => %w[parent_name email password login_url],
    'application_status_update' => %w[parent_name status login_url]
  }.freeze

  # Human-readable description of each token and where its value comes from.
  # Shown as helper text in the template editor and the Help Center.
  TOKEN_INFO = {
    'parent_name' => "The parent/guardian's first name, from the application.",
    'child_name' => "The child's first name, from the application.",
    'program_name' => "The program's name (e.g. 2026-2027 Nature Preschool Program).",
    'program_dates' => "The program's start and end dates.",
    'class_days' => "The days class meets, from the program's Class Days field.",
    'time_range' => "The program's start-end time.",
    'tuition' => "The family's tuition amount. Uses a custom tuition if you've set one on the application (Tuition tab -> Edit Fees); otherwise the program's standard rate.",
    'enrollment_fee' => "The enrollment fee. Uses a custom fee if set on the application; otherwise the program default ($150).",
    'enrollment_link' => "A personalized link to the enrollment application form for this family.",
    'meeting_datetime' => "The scheduled meet-and-greet date and time.",
    'location_name' => "The meeting location's name.",
    'location_address' => "The meeting location's street address.",
    'handbook_url' => "The Family Handbook link (set once for the whole school).",
    'date_options' => "The meet-and-greet times you proposed, shown as clickable links the family picks from.",
    'payment_link' => "A personalized link to the family's payment-plan selection and enrollment-fee page.",
    'login_url' => "A link to the family portal sign-in page.",
    'password' => "The family's temporary password for their new portal account.",
    'email' => "The parent's email address (also their portal login).",
    'status' => "The application's current status.",
    'payment_plan_summary' => "A summary of the family's selected payment plan and installment amount."
  }.freeze

  # The starting copy for each workflow email. Editable in the portal;
  # deleting a template restores this wording on the next visit.
  DEFAULT_TEMPLATES = {
    'enrollment_invite' => {
      name: "You're Invited to Apply",
      subject: "You're Invited to Apply: {{program_name}}",
      body: <<~BODY
        Hi {{parent_name}},

        Thank you for your interest in Earthkin's Nature Preschool drop-off program! Our 100% outdoor program runs {{program_dates}}, meeting weekly on {{class_days}} from {{time_range}}. We maintain a low teacher-to-student ratio to engage in meaningful child-led, play- and nature-based early learning.

        Enrollment is for the full school year, and tuition is ${{tuition}}, with flexible payment plan options available. If you are interested in enrolling more than one child, ask us about our sibling discount! The enrollment process includes:
        - Submission of an enrollment application for each child
        - A meet-and-greet with the director
        - Payment of the non-refundable ${{enrollment_fee}} enrollment fee to reserve your child(ren)'s spot
        - Completion of final enrollment forms

        Please fill out the Enrollment Application for each child you are interested in enrolling and we'll follow up soon with next steps:
        {{enrollment_link}}

        Kindly,
        The Earthkin Team
      BODY
    },
    'meeting_invite' => {
      name: 'Schedule A Meet-n-Greet',
      subject: "\u{1F33F} Nature Preschool: Schedule A Meet-n-Greet",
      body: <<~BODY
        Hi {{parent_name}},

        I hope this email finds you in good health and spirits! Thank you for taking the time to thoughtfully fill out the enrollment application for our Nature Preschool program. We would love to welcome {{child_name}} and your family to move forward with the next phase of enrollment.

        Program Details:
        - {{class_days}}, {{program_dates}}
        - {{time_range}}
        - Tuition: ${{tuition}}

        A ${{enrollment_fee}} non-refundable enrollment fee is due upon enrollment to reserve your child's spot in the program.

        If you'd like to continue the enrollment process, the next step is gathering together for a meet-and-greet at {{location_name}} with the director, Sydney Gary. Spending time together in the space will give us all an opportunity to explore the environment, answer questions, and make sure the nature preschool feels like a good fit for your family.

        Please click the date that works best for your family:
        {{date_options}}

        Warmly,
        The Nature Preschool Team
      BODY
    },
    'meeting_scheduled' => {
      name: 'Meet-n-Greet Scheduled',
      subject: "\u{1F33F} Nature Preschool: Meet-n-Greet Scheduled - {{meeting_datetime}}",
      body: <<~BODY
        Hi {{parent_name}},

        I hope this email finds you in good health and spirits! Thank you for selecting a date for the Earthkin Nature School Meet-n-Greet. Please see your confirmation and details below.

        Meeting Details:
        - Date & Time: {{meeting_datetime}}
        - Location: {{location_name}}
        - Address: {{location_address}}

        Spending time together in the space will give us all an opportunity to explore the environment, answer questions, and make sure the nature preschool feels like a good fit for your family.

        Before the meet-n-greet, please review our Family Handbook so you can come ready with questions: {{handbook_url}}

        Please don't hesitate to reach out with any questions. We look forward to connecting with you!

        Warmly,
        The Nature Preschool Team
      BODY
    },
    'enrollment_fee_request' => {
      name: 'Next Steps: Enrollment Fee & Handbook',
      subject: 'Next Steps: Enrollment Fee & Handbook',
      body: <<~BODY
        Hi {{parent_name}},

        Thank you again for meeting with us at {{location_name}}! We really enjoyed spending time with your family and getting to know {{child_name}} a bit more. It was wonderful to connect and share more about Earthkin together.

        Please see the information below for next steps toward enrollment.

        To Reserve Your Spot
        To reserve {{child_name}}'s spot, please select your preferred payment plan and submit the non-refundable ${{enrollment_fee}} enrollment fee:
        {{payment_link}}

        Before Completing Final Forms
        Please review our Family Handbook to familiarize yourself with our policies and procedures: {{handbook_url}}

        The first tuition installment payment will be due according to the payment plan you select.

        Once the enrollment fee is submitted and the handbook has been reviewed, we'll send over the final enrollment forms including:
        - Family Agreement & Waiver
        - Parent/Guardian Contact
        - Medication Administration Form
        - Health & Medical Care Form

        Feel free to reach out anytime with questions. We're so grateful for your interest in Earthkin and look forward to the possibility of having your family in our community!

        Warmly,
        The Nature Preschool Team
      BODY
    },
    'enrollment_forms' => {
      name: 'Action Required: Enrollment Forms',
      subject: 'Action Required: Enrollment Forms for {{program_name}}',
      body: <<~BODY
        Hi {{parent_name}},

        Thank you for your enrollment fee payment! {{child_name}}'s spot in {{program_name}} is now secured.

        To complete the enrollment process, please review and sign the following forms in your parent portal:
        - Family Agreement & Waiver — our policies and liability waiver
        - Parent/Guardian Contact Form — emergency contacts and pickup authorization
        - Medication Administration Form — if your child requires any medication
        - Health & Medical Care Form — medical history and care preferences

        Sign in and go to Forms to review and sign each one:
        {{login_url}}

        What's Next?
        1. Sign the enrollment forms online
        2. We'll confirm your enrollment once all forms are signed
        3. Your first tuition installment will be due according to your payment plan
        4. Mark your calendar for the first day of {{program_name}}!

        If you have any questions about the forms or the program, please don't hesitate to reach out.

        We're so excited to welcome {{child_name}} to our nature-based learning community!

        Warmly,
        The Nature Preschool Team
      BODY
    },
    'enrollment_confirmed' => {
      name: 'Enrollment Confirmed',
      subject: "Enrollment Confirmed for {{child_name}}! \u{1F389}",
      body: <<~BODY
        Hi,

        We're thrilled to officially welcome {{child_name}} to {{program_name}}! Your enrollment is now confirmed and your child's spot for the year is secured.

        Enrollment Summary
        - Child: {{child_name}}
        - Program: {{program_name}}
        - Dates: {{program_dates}}
        - Class days: {{class_days}}

        Your Payment Plan
        {{payment_plan_summary}}

        What's Next?
        - Watch for Meet-the-Teacher opportunity announcements and first-day details
        - Tuition installments follow your selected plan
        - Reach out any time with questions

        We can't wait to explore, play, and learn with {{child_name}} in nature this year!

        Warmly,
        The Nature Preschool Team
      BODY
    },
    'welcome_email' => {
      name: 'Parent Welcome & Login',
      subject: 'Welcome to Earthkin Nature School - Your Account is Ready!',
      body: <<~BODY
        Hi {{parent_name}},

        Welcome to Earthkin Nature School! A parent account has been created for you so you can view your enrollments, calendar, payments, and enrollment forms.

        Your login details:
        - Email: {{email}}
        - Temporary password: {{password}}

        Log in here: {{login_url}}

        Please change your password after your first login using the "Forgot password?" link on the sign-in screen.

        Warmly,
        The Nature Preschool Team
      BODY
    },
    'application_status_update' => {
      name: 'Application Status Update',
      subject: 'Update on Your Enrollment Application',
      body: <<~BODY
        Hi {{parent_name}},

        There's an update on your enrollment application: it is now {{status}}.

        You can view the details in your parent portal: {{login_url}}

        Warmly,
        The Nature Preschool Team
      BODY
    }
  }.freeze

  validates :name, :subject, :body, presence: true
  validates :key, uniqueness: { conditions: -> { where(deleted_at: nil) } }, inclusion: { in: KNOWN_KEYS.keys }, allow_nil: true
  validate :tokens_must_be_valid

  def self.for(key)
    find_by(key: key)
  end

  def deleted_label
    name
  end

  # Idempotently create the editable template for every workflow email so
  # admins always see (and can edit) the current wording. Deleting a
  # template restores the default here on the next listing.
  def self.ensure_defaults!
    DEFAULT_TEMPLATES.each do |key, attrs|
      find_or_create_by!(key: key) do |template|
        template.name = attrs[:name]
        template.subject = attrs[:subject]
        template.body = attrs[:body].strip
      end
    end
  end

  def rendered_subject(vars = {})
    interpolate(subject, vars)
  end

  # Body with tokens substituted, still plain text (used to prefill the
  # manual email composer).
  def rendered_text(vars = {})
    interpolate(body, vars)
  end

  # Plain text body -> simple HTML: {{placeholders}} substituted (URLs become
  # links), blank lines split paragraphs.
  def rendered_html(vars = {})
    escaped = ERB::Util.html_escape(body)
    substituted = escaped.gsub(/{{\s*(\w+)\s*}}/) do
      value = (vars[Regexp.last_match(1).to_sym] || vars[Regexp.last_match(1)]).to_s
      linkify(ERB::Util.html_escape(value))
    end
    substituted.split(/\r?\n\r?\n+/).map { |para| "<p>#{para.gsub(/\r?\n/, '<br>')}</p>" }.join("\n")
  end

  private

  def linkify(escaped_text)
    escaped_text.gsub(%r{https?://[^\s<]+}) do |url|
      %(<a href="#{url}">#{url}</a>)
    end
  end

  # Guard rails for the template editor: a keyed (workflow) template may only
  # use its known tokens, and stray braces are rejected so a half-deleted
  # token can't silently break the email.
  def tokens_must_be_valid
    return if key.blank?

    allowed = KNOWN_KEYS[key] || []
    combined = "#{subject}\n#{body}"
    used = combined.scan(/{{\s*(\w+)\s*}}/).flatten.uniq

    unknown = used - allowed
    errors.add(:base, "Unknown token(s): #{unknown.map { |t| "{{#{t}}}" }.join(', ')}") if unknown.any?

    if combined.gsub(/{{\s*\w+\s*}}/, '').match?(/[{}]/)
      errors.add(:base, 'There is a broken token — check for stray { or } characters')
    end
  end

  def interpolate(text, vars)
    text.gsub(/{{\s*(\w+)\s*}}/) do
      (vars[Regexp.last_match(1).to_sym] || vars[Regexp.last_match(1)]).to_s
    end
  end
end
