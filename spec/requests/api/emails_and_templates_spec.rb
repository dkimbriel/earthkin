require 'rails_helper'

RSpec.describe 'Api::Emails and Api::EmailTemplates', type: :request do
  let(:admin) { create(:user) }

  before { sign_in admin }

  describe 'email templates' do
    it 'creates a workflow override and the mailer uses it' do
      post '/api/email_templates', params: {
        email_template: {
          key: 'enrollment_confirmed',
          name: 'Enrollment Confirmed',
          subject: 'Welcome {{child_name}}!',
          body: "Hi there,\n\n{{child_name}} is officially enrolled in {{program_name}}.\n\nSee you soon!"
        }
      }
      expect(response).to have_http_status(:created)

      family = create(:family)
      create(:parent, family: family, email: 'mom@example.com')
      child = create(:child, family: family, first_name: 'Fern')
      program = create(:program, name: 'Forest Explorers')
      enrollment = create(:program_enrollment, child: child, program: program)

      mail = EnrollmentMailer.enrollment_confirmed(enrollment.id)
      expect(mail.subject).to eq('Welcome Fern!')
      expect(mail.body.encoded).to include('officially enrolled in Forest Explorers')
    end

    it 'rejects unknown override keys' do
      post '/api/email_templates', params: {
        email_template: { key: 'nope', name: 'X', subject: 'S', body: 'B' }
      }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'lists a pre-populated template for every workflow email' do
      create(:email_template, name: 'My Manual Template')

      get '/api/email_templates'

      json = JSON.parse(response.body)
      expect(json['templates'].map { |t| t['key'] }.compact).to match_array(EmailTemplate::KNOWN_KEYS.keys)
      expect(json['templates'].map { |t| t['name'] }).to include('My Manual Template')
      expect(json['known_keys']).to have_key('enrollment_fee_request')

      fee_template = json['templates'].find { |t| t['key'] == 'enrollment_fee_request' }
      expect(fee_template['body']).to include('{{payment_link}}')
    end

    it 'recreates the default wording after a workflow template is deleted' do
      get '/api/email_templates'
      template = EmailTemplate.for('welcome_email')
      template.update!(body: 'Custom wording {{parent_name}}')

      delete "/api/email_templates/#{template.id}"
      expect(response).to have_http_status(:no_content)

      get '/api/email_templates'
      expect(EmailTemplate.for('welcome_email').body).to include('Welcome to Earthkin Nature School!')
    end

    it 'rejects unknown tokens and broken braces on workflow templates' do
      get '/api/email_templates'
      template = EmailTemplate.for('welcome_email')

      patch "/api/email_templates/#{template.id}", params: {
        email_template: { body: 'Hi {{parent_nam}}' }
      }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('Unknown token')

      patch "/api/email_templates/#{template.id}", params: {
        email_template: { body: 'Hi {{parent_name}, broken brace' }
      }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('broken token')
    end

    it 'renders the meeting invite from a template with clickable date links' do
      get '/api/email_templates' # seeds defaults

      application = create(:enrollment_application, parent_first_name: 'Dana')
      event = create(:event, eventable: application, event_type: 'meet_and_greet',
                     status: 'pending_selection',
                     proposed_dates: [1.week.from_now.iso8601, 2.weeks.from_now.iso8601])

      mail = EnrollmentMailer.meeting_invite(event.id, 'https://example.org')
      body = mail.html_part ? mail.html_part.body.decoded : mail.body.decoded
      expect(body).to include('Sydney Gary')
      expect(body).to include("https://example.org/meetings/#{event.confirmation_token}/confirm?date=")
      expect(body).to include('<a href="https://example.org/meetings/')
    end

    it 'sends workflow emails using the default template with tokens filled in' do
      get '/api/email_templates' # seeds the defaults

      family = create(:family)
      create(:parent, family: family, email: 'mom@example.com')
      child = create(:child, family: family, first_name: 'Fern')
      program = create(:program, name: 'Forest Explorers')
      enrollment = create(:program_enrollment, child: child, program: program)

      mail = EnrollmentMailer.enrollment_confirmed(enrollment.id)
      expect(mail.subject).to include('Enrollment Confirmed for Fern!')
      expect(mail.body.encoded).to include('officially welcome Fern to Forest Explorers')
      expect(mail.body.encoded).not_to include('{{')
    end

    it 'is admin-only' do
      sign_in create(:user, :teacher)

      get '/api/email_templates'

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'manual emails' do
    it 'drafts, edits, and sends an email' do
      post '/api/emails', params: {
        email: { recipient: 'someone@example.com', subject: 'Hello', body: "First draft.\n\nBye." }
      }
      expect(response).to have_http_status(:created)
      draft = Email.last
      expect(draft.status).to eq('draft')
      expect(draft.html_body).to include('<p>First draft.</p>')

      patch "/api/emails/#{draft.id}", params: {
        email: { subject: 'Hello again', body: 'Second draft.' }
      }
      expect(draft.reload.subject).to eq('Hello again')
      expect(draft.metadata['body']).to eq('Second draft.')

      expect {
        post "/api/emails/#{draft.id}/deliver"
      }.to change { ActionMailer::Base.deliveries.count }.by(1)

      expect(response).to have_http_status(:ok)
      expect(draft.reload.status).to eq('sent')
      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to eq(['someone@example.com'])
      expect(mail.subject).to eq('Hello again')
    end

    it 'refuses to edit or delete sent emails' do
      email = create(:email, status: 'sent')

      patch "/api/emails/#{email.id}", params: { email: { subject: 'X' } }
      expect(response).to have_http_status(:unprocessable_content)

      delete "/api/emails/#{email.id}"
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'deletes drafts' do
      post '/api/emails', params: {
        email: { recipient: 'x@example.com', subject: 'Draft', body: 'B' }
      }
      draft = Email.last

      expect {
        delete "/api/emails/#{draft.id}"
      }.to change(Email, :count).by(-1)
    end

    it 'prefills recipient from a parent' do
      parent = create(:parent, family: create(:family), email: 'parent@example.com')

      post '/api/emails', params: {
        email: { parent_id: parent.id, subject: 'Hi', body: 'B' }
      }

      expect(Email.last.recipient).to eq('parent@example.com')
      expect(Email.last.emailable).to eq(parent)
    end

    it 'links drafts started from an application to its email timeline' do
      application = create(:enrollment_application)

      post '/api/emails', params: {
        email: {
          recipient: application.parent_email,
          subject: 'Fee reminder',
          body: 'B',
          email_type: 'enrollment_fee_request',
          enrollment_application_id: application.id
        }
      }

      email = Email.last
      expect(email.emailable).to eq(application)
      expect(email.email_type).to eq('enrollment_fee_request')
      expect(application.emails).to include(email)
    end
  end

  describe 'GET /api/enrollment_applications/:id/email_draft' do
    it 'returns the workflow email with tokens resolved for editing' do
      program = create(:program, name: 'Forest Explorers')
      application = create(:enrollment_application, program: program,
                           parent_first_name: 'Dana', parent_email: 'dana@example.com')

      get "/api/enrollment_applications/#{application.id}/email_draft", params: { email_type: 'enrollment_fee_request' }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['recipient']).to eq('dana@example.com')
      expect(json['email_type']).to eq('enrollment_fee_request')
      expect(json['enrollment_application_id']).to eq(application.id)
      expect(json['body']).to include('Hi Dana')
      expect(json['body']).not_to include('{{')
    end

    it 'errors helpfully when prerequisites are missing' do
      application = create(:enrollment_application)

      get "/api/enrollment_applications/#{application.id}/email_draft", params: { email_type: 'meeting_scheduled' }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('No meeting scheduled yet')
    end
  end
end
