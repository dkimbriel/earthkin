require 'rails_helper'

RSpec.describe 'Staff documents', type: :request do
  let(:admin) { create(:user) }
  let(:teacher_user) { create(:user, :teacher) }
  let!(:teacher) { create(:teacher, user: teacher_user) }
  let(:other_teacher) { create(:teacher) }

  def json_response
    JSON.parse(response.body)
  end

  def issue_document(to: teacher)
    StaffDocument.issue!(
      teacher: to, issued_by: admin, title: 'Termination Letter',
      body: "# Notice\n\nYour employment ends September 16, 2026.\n\n[[signature]]",
      employee_position: 'Lead Teacher'
    )
  end

  describe 'access control' do
    it 'lets an employee see only their own documents' do
      mine = issue_document
      issue_document(to: other_teacher)
      sign_in teacher_user

      get '/api/staff_documents'

      expect(response).to have_http_status(:ok)
      expect(json_response.map { |d| d['id'] }).to eq([mine.id])
    end

    it "404s when an employee opens someone else's document" do
      theirs = issue_document(to: other_teacher)
      sign_in teacher_user

      get "/api/staff_documents/#{theirs.id}"

      expect(response).to have_http_status(:not_found)
    end

    it 'shows admins every document' do
      issue_document
      issue_document(to: other_teacher)
      sign_in admin

      get '/api/staff_documents'

      expect(json_response.size).to eq(2)
    end

    it 'forbids parents entirely' do
      sign_in create(:user, :parent)

      get '/api/staff_documents'

      expect(response).to have_http_status(:forbidden)
    end

    it 'forbids a teacher from issuing a document' do
      sign_in teacher_user

      post '/api/staff_documents', params: { teacher_id: teacher.id, title: 'Notice', body: 'Text.' }

      expect(response).to have_http_status(:forbidden)
    end

    it 'shows nothing to a teacher account with no teacher record' do
      issue_document
      sign_in create(:user, :teacher)

      get '/api/staff_documents'

      expect(json_response).to be_empty
    end
  end

  describe 'issuing' do
    it 'copies the resolved text onto the document' do
      template = FormTemplate.create!(
        key: 'staff_issue', name: 'Notice', category: 'staff',
        body: 'Notice for {{employee_name}}.'
      )
      sign_in admin

      post '/api/staff_documents', params: {
        teacher_id: teacher.id, form_template_id: template.id,
        title: 'Termination Letter', employee_position: 'Lead Teacher'
      }

      expect(response).to have_http_status(:created)
      expect(json_response['body']).to include(teacher.full_name)
      expect(json_response['status']).to eq('pending')
    end

    it 'exposes the staff templates and employees to pick from' do
      sign_in admin

      get '/api/staff_documents/templates'

      expect(json_response['templates'].map { |t| t['key'] }).to include('termination_letter')
      expect(json_response['templates'].map { |t| t['category'] }.uniq).to eq(['staff'])
      expect(json_response['known_tokens']).to include('employee_name')
    end
  end

  describe 'signing' do
    it 'lets an employee sign their own document, despite teachers being view-only elsewhere' do
      document = issue_document
      sign_in teacher_user

      post "/api/staff_documents/#{document.id}/sign", params: {
        signed_by_name: teacher.full_name, employee_comments: 'I disagree with item 3.'
      }

      expect(response).to have_http_status(:ok)
      expect(json_response['status']).to eq('partially_signed')
      expect(document.reload.employee_signed_by_name).to eq(teacher.full_name)
      expect(document.employee_comments).to eq('I disagree with item 3.')
      expect(document.employee_signed_by_email).to eq(teacher_user.email)
    end

    it 'notifies the school when an employee acknowledges a document' do
      document = issue_document
      sign_in teacher_user

      expect {
        post "/api/staff_documents/#{document.id}/sign", params: { signed_by_name: teacher.full_name }
      }.to change { Notification.where(event_type: 'staff_document_signed').count }.by(1)
    end

    it 'counter-signs when an admin signs' do
      document = issue_document
      sign_in admin

      post "/api/staff_documents/#{document.id}/sign", params: { signed_by_name: 'Sydney Gary' }

      document.reload
      expect(document.director_signed_by_name).to eq('Sydney Gary')
      expect(document.employee_signed_at).to be_nil
      expect(document.status).to eq('partially_signed')
    end

    it 'completes the document once both parties have signed' do
      document = issue_document
      sign_in teacher_user
      post "/api/staff_documents/#{document.id}/sign", params: { signed_by_name: teacher.full_name }

      sign_in admin
      post "/api/staff_documents/#{document.id}/sign", params: { signed_by_name: 'Sydney Gary' }

      expect(json_response['status']).to eq('signed')
    end

    it 'rejects a signature with no name' do
      document = issue_document
      sign_in teacher_user

      post "/api/staff_documents/#{document.id}/sign", params: { signed_by_name: '' }

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['error']).to match(/name is required/)
    end

    it "refuses to let an employee sign another employee's document" do
      theirs = issue_document(to: other_teacher)
      sign_in teacher_user

      post "/api/staff_documents/#{theirs.id}/sign", params: { signed_by_name: teacher.full_name }

      expect(response).to have_http_status(:not_found)
      expect(theirs.reload.employee_signed_at).to be_nil
    end

    it 'records a view in the audit trail' do
      document = issue_document
      sign_in teacher_user

      post "/api/staff_documents/#{document.id}/view"

      expect(response).to have_http_status(:ok)
      expect(document.reload.audit_log.map { |e| e['event'] }).to include('viewed')
    end
  end

  describe 'PDF' do
    it 'renders a PDF for the employee' do
      document = issue_document
      document.sign_as_employee!(name: teacher.full_name)
      sign_in teacher_user

      get "/api/staff_documents/#{document.id}/pdf"

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to eq('application/pdf')
      expect(response.body[0, 4]).to eq('%PDF')
    end
  end
end
