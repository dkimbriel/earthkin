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

    it 'signs a form recording name, time, and form snapshot' do
      signature = child.enrollment_form_signatures.first

      post "/api/portal/forms/#{signature.id}/sign", params: { signed_by_name: 'Jane Parent' }

      expect(response).to have_http_status(:ok)
      signature.reload
      expect(signature.status).to eq('signed')
      expect(signature.signed_by_name).to eq('Jane Parent')
      expect(signature.signed_at).to be_present
      expect(signature.signed_by_email).to eq(parent_user.email)
      expect(signature.form_body_snapshot).to eq(signature.form_template.body)
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
