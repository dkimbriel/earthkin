require 'rails_helper'

RSpec.describe 'Enrollment form signatures', type: :request do
  let(:family) { create(:family) }
  let!(:child) { create(:child, family: family) }
  let(:parent_user) { create(:user, :parent) }
  let!(:parent) { create(:parent, family: family, user: parent_user) }
  let(:admin) { create(:user) }

  describe 'issuing forms' do
    it 'creates the four standard pending forms for a child' do
      sign_in admin

      expect {
        post '/api/enrollment_form_signatures', params: { child_id: child.id }
      }.to change(EnrollmentFormSignature, :count).by(4)

      expect(response).to have_http_status(:created)
      expect(child.enrollment_form_signatures.pending.count).to eq(4)
    end

    it 'is idempotent' do
      sign_in admin

      post '/api/enrollment_form_signatures', params: { child_id: child.id }
      expect {
        post '/api/enrollment_form_signatures', params: { child_id: child.id }
      }.not_to change(EnrollmentFormSignature, :count)
    end

    it 'issues forms automatically when enrollment forms are sent' do
      program = create(:program)
      application = create(:enrollment_application, program: program, status: 'fee_paid', child: child, family: family)

      expect {
        EnrollmentWorkflowService.new(application).send_enrollment_forms
      }.to change(EnrollmentFormSignature, :count).by(4)
    end
  end

  describe 'parent portal signing' do
    before do
      sign_in admin
      post '/api/enrollment_form_signatures', params: { child_id: child.id }
      sign_out admin
      sign_in parent_user
    end

    it 'lists the family forms with their text' do
      get '/api/portal/forms'

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.length).to eq(4)
      expect(json.map { |f| f['status'] }.uniq).to eq(['pending'])
      expect(json.first['form_body']).to be_present
    end

    it 'signs a form recording name, time, answers, and form snapshot' do
      signature = child.enrollment_form_signatures.first

      post "/api/portal/forms/#{signature.id}/sign", params: {
        signed_by_name: 'Jane Parent',
        response_text: "1. Answer one\n2. Answer two"
      }

      expect(response).to have_http_status(:ok)
      signature.reload
      expect(signature.status).to eq('signed')
      expect(signature.signed_by_name).to eq('Jane Parent')
      expect(signature.signed_at).to be_present
      expect(signature.signed_by_email).to eq(parent_user.email)
      expect(signature.form_body_snapshot).to eq(signature.form_template.body)
      expect(signature.response_text).to include('Answer one')
    end

    it 'stores inline form field values, filtering junk keys and nested payloads' do
      signature = child.enrollment_form_signatures.first

      post "/api/portal/forms/#{signature.id}/sign", params: {
        signed_by_name: 'Jane Parent',
        form_fields: {
          child_full_name: 'Mayu K',
          media_permission: 'true',
          'bad key!' => 'nope',
          nested: { evil: 'payload' }
        }
      }

      expect(response).to have_http_status(:ok)
      fields = signature.reload.form_fields
      expect(fields['child_full_name']).to eq('Mayu K')
      expect(fields['media_permission']).to be true
      expect(fields).not_to have_key('bad key!')
      expect(fields['nested']).to be_a(String) # flattened, never a nested hash
    end

    it 'refuses to sign while required fields are missing' do
      signature = child.enrollment_form_signatures.first
      signature.form_template.update!(body: <<~BODY)
        # Test Form
        Name: [[text:child_full_name|Child's full name*]]
        [[checkbox:opt_a|Option A]]
        [[checkbox:opt_b|Option B]]
        [[require-one:opt_a,opt_b|Please choose A or B]]
        [[signature]]
      BODY

      post "/api/portal/forms/#{signature.id}/sign", params: { signed_by_name: 'Jane Parent' }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Child's full name")
      expect(response.body).to include('Please choose A or B')
      expect(signature.reload.status).to eq('pending')

      post "/api/portal/forms/#{signature.id}/sign", params: {
        signed_by_name: 'Jane Parent',
        form_fields: { child_full_name: 'Demo Kid', opt_a: 'true' }
      }

      expect(response).to have_http_status(:ok)
      expect(signature.reload.status).to eq('signed')
    end

    it 'keeps a DocuSign-style audit trail: issued, viewed, signed with checksum' do
      signature = child.enrollment_form_signatures.first
      expect(signature.audit_log.map { |e| e['event'] }).to eq(['issued'])

      post "/api/portal/forms/#{signature.id}/view"
      expect(response).to have_http_status(:ok)

      post "/api/portal/forms/#{signature.id}/sign", params: { signed_by_name: 'Jane Parent' }

      log = signature.reload.audit_log
      expect(log.map { |e| e['event'] }).to eq(%w[issued viewed signed])

      viewed = log.find { |e| e['event'] == 'viewed' }
      expect(viewed['by']).to eq(parent_user.email)
      expect(viewed['ip']).to be_present

      signed = log.find { |e| e['event'] == 'signed' }
      expect(signed['by']).to eq('Jane Parent')
      expect(signed['document_sha256']).to eq(Digest::SHA256.hexdigest(signature.form_template.body))
    end

    it 'blocks cross-family view tracking' do
      other_child = create(:child, family: create(:family))
      sign_in admin
      post '/api/enrollment_form_signatures', params: { child_id: other_child.id }
      sign_out admin
      sign_in parent_user

      post "/api/portal/forms/#{other_child.enrollment_form_signatures.first.id}/view"

      expect(response).to have_http_status(:not_found)
    end

    it 'rejects signing without a name' do
      signature = child.enrollment_form_signatures.first

      post "/api/portal/forms/#{signature.id}/sign", params: { signed_by_name: '' }

      expect(response).to have_http_status(:unprocessable_content)
      expect(signature.reload.status).to eq('pending')
    end

    it 'cannot sign forms from another family' do
      other_child = create(:child, family: create(:family))
      sign_in admin
      post '/api/enrollment_form_signatures', params: { child_id: other_child.id }
      sign_out admin
      sign_in parent_user

      other_signature = other_child.enrollment_form_signatures.first
      post "/api/portal/forms/#{other_signature.id}/sign", params: { signed_by_name: 'Sneaky' }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'staff paperwork view' do
    it 'returns signatures for a family' do
      sign_in admin
      post '/api/enrollment_form_signatures', params: { child_id: child.id }
      child.enrollment_form_signatures.first.sign!(name: 'Jane Parent')

      get '/api/enrollment_form_signatures', params: { family_id: family.id }

      json = JSON.parse(response.body)
      expect(json.length).to eq(4)
      expect(json.count { |s| s['status'] == 'signed' }).to eq(1)
    end
  end

  describe 'PDF downloads' do
    before do
      sign_in admin
      post '/api/enrollment_form_signatures', params: { child_id: child.id }
    end

    it 'parents download their own forms as PDF (pending and signed)' do
      sign_in parent_user
      signature = child.enrollment_form_signatures.first

      get "/api/portal/forms/#{signature.id}/pdf"
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to eq('application/pdf')
      expect(response.body[0, 4]).to eq('%PDF')

      signature.sign!(name: 'Jane Parent', email: parent_user.email, form_fields: { 'child_full_name' => 'Demo Kid' })

      get "/api/portal/forms/#{signature.id}/pdf"
      expect(response).to have_http_status(:ok)
      expect(response.body[0, 4]).to eq('%PDF')
    end

    it 'blocks parents from other families PDFs' do
      other_child = create(:child, family: create(:family))
      post '/api/enrollment_form_signatures', params: { child_id: other_child.id }
      sign_in parent_user

      get "/api/portal/forms/#{other_child.enrollment_form_signatures.first.id}/pdf"

      expect(response).to have_http_status(:not_found)
    end

    it 'staff download signed forms with the certificate' do
      signature = child.enrollment_form_signatures.first
      signature.sign!(name: 'Jane Parent')

      get "/api/enrollment_form_signatures/#{signature.id}/pdf"

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to eq('application/pdf')
    end
  end

  describe 'form templates' do
    it 'admins can edit form text' do
      sign_in admin
      get '/api/form_templates'
      template = JSON.parse(response.body).first

      patch "/api/form_templates/#{template['id']}", params: {
        form_template: { body: 'Updated waiver text.' }
      }

      expect(response).to have_http_status(:ok)
      expect(FormTemplate.find(template['id']).body).to eq('Updated waiver text.')
    end
  end
end
