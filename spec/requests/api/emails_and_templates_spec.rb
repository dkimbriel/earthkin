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
  end
end
