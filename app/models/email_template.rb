class EmailTemplate < ApplicationRecord
  # Workflow emails that can be edited, with the placeholders each supports.
  KNOWN_KEYS = {
    'enrollment_invite' => %w[parent_name program_name program_dates class_days time_range tuition enrollment_fee enrollment_link],
    'meeting_scheduled' => %w[parent_name child_name program_name meeting_datetime location_name location_address handbook_url],
    'enrollment_fee_request' => %w[parent_name child_name enrollment_fee payment_link location_name handbook_url],
    'enrollment_forms' => %w[parent_name child_name program_name login_url],
    'enrollment_confirmed' => %w[child_name program_name program_dates class_days payment_plan_summary],
    'welcome_email' => %w[parent_name email password login_url],
    'application_status_update' => %w[parent_name status login_url]
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
  validates :key, uniqueness: true, inclusion: { in: KNOWN_KEYS.keys }, allow_nil: true

  def self.for(key)
    find_by(key: key)
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
