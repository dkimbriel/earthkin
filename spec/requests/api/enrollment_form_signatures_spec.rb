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

    it "emails the family their forms are ready, sourced from the child's enrollment" do
      program = create(:program)
      create(:program_enrollment, child: child, program: program)
      sign_in admin

      expect {
        post '/api/enrollment_form_signatures', params: { child_id: child.id }
      }.to change { Email.where(email_type: 'enrollment_forms_notice').count }.by(1)

      email = Email.where(email_type: 'enrollment_forms_notice').last
      expect(email.recipient).to eq(parent.email)
      expect(email.status).to eq('sent')
    end

    it 'still issues forms but sends no email when the child has no enrollment' do
      sign_in admin

      expect {
        post '/api/enrollment_form_signatures', params: { child_id: child.id }
      }.not_to change { Email.where(email_type: 'enrollment_forms_notice').count }

      expect(child.enrollment_form_signatures.count).to eq(4)
    end

    it 'does not re-email when forms were already issued' do
      create(:program_enrollment, child: child, program: create(:program))
      sign_in admin
      post '/api/enrollment_form_signatures', params: { child_id: child.id }

      expect {
        post '/api/enrollment_form_signatures', params: { child_id: child.id }
      }.not_to change { Email.where(email_type: 'enrollment_forms_notice').count }
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

    it 'expands [[payment-plans]] from the database and snapshots the expansion' do
      program = create(:program)
      plan_a = create(:payment_plan, program: program, name: 'Pay In Full', installment_count: 1, total_amount: 2800, display_order: 1)
      plan_b = create(:payment_plan, program: program, name: 'Ten Months', installment_count: 10, total_amount: 2800, display_order: 2)
      enrollment = create(:program_enrollment, child: child, program: program)
      create(:enrollment_payment_plan, program_enrollment: enrollment, payment_plan: plan_b)

      signature = child.enrollment_form_signatures.first
      signature.form_template.update!(body: "# Agreement\n\nPick a plan:\n\n[[payment-plans]]\n\n[[signature]]")

      get '/api/portal/forms'
      form = JSON.parse(response.body).find { |f| f['id'] == signature.id }

      expect(form['form_body']).to include('Pay In Full')
      expect(form['form_body']).to include('Ten Months')
      expect(form['form_body']).to include("[[checkbox:plan_#{plan_a.id}|")
      expect(form['form_body']).to include("[[require-one:plan_#{plan_a.id},plan_#{plan_b.id}|")
      expect(form['form_body']).not_to include('[[payment-plans]]')
      # The plan the enrollment already uses comes pre-checked.
      expect(form['suggested_fields']).to eq({ "plan_#{plan_b.id}" => true })

      # Signing without choosing a plan is rejected; the snapshot records the
      # expanded document.
      post "/api/portal/forms/#{signature.id}/sign", params: { signed_by_name: 'Jane Parent' }
      expect(response).to have_http_status(:unprocessable_content)

      post "/api/portal/forms/#{signature.id}/sign", params: {
        signed_by_name: 'Jane Parent',
        form_fields: { "plan_#{plan_b.id}" => 'true' }
      }
      expect(response).to have_http_status(:ok)
      expect(signature.reload.form_body_snapshot).to include('Ten Months')
      expect(signature.form_body_snapshot).not_to include('[[payment-plans]]')
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

    it 'waives all requirements when the no-medication checkbox is checked' do
      signature = child.enrollment_form_signatures.first
      signature.form_template.update!(body: <<~BODY)
        # Medication Form
        [[checkbox:no_medication|My child does not have any medication that needs to be administered while at Earthkin Nature School]]
        [[waive-required-if:no_medication]]
        Medication Name: [[text:medication_name|Medication name*]]
        [[checkbox:is_prescribed|Prescribed]]
        [[checkbox:is_otc|Over-the-counter]]
        [[require-one:is_prescribed,is_otc|Please indicate prescribed or OTC]]
        [[signature]]
      BODY

      # Without the waiver, requirements still block signing.
      post "/api/portal/forms/#{signature.id}/sign", params: { signed_by_name: 'Jane Parent' }
      expect(response).to have_http_status(:unprocessable_content)

      # Checking the no-medication box waives everything.
      post "/api/portal/forms/#{signature.id}/sign", params: {
        signed_by_name: 'Jane Parent',
        form_fields: { no_medication: 'true' }
      }
      expect(response).to have_http_status(:ok)
      expect(signature.reload.status).to eq('signed')
      expect(signature.form_fields['no_medication']).to be true
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

  describe '[[tuition-plan]] token' do
    it "renders only the child's own rate, plan, and 24th-of-month due dates" do
      program = create(:program, start_date: Date.new(2026, 8, 24))
      plan = create(:payment_plan, program: program, name: 'Sibling Monthly', installment_count: 10, total_amount: 2520)
      enrollment = create(:program_enrollment, child: child, program: program)
      enrollment.create_enrollment_payment_plan!(
        payment_plan: plan, total_amount: 2520, enrollment_fee: 150,
        installments: plan.generate_schedule(program.start_date).map { |i| i.merge('paid_at' => nil) }
      )
      template = FormTemplate.find_or_create_by!(key: 'family_agreement') { |t| t.name = 'Family Agreement & Waiver' }
      template.update!(body: "# Agreement\n\n[[tuition-plan]]\n\n[[signature]]")
      sig = EnrollmentFormSignature.create!(child: child, form_template: template, enrollment_application: nil)

      body = sig.rendered_body
      expect(body).to include('Tuition for')
      expect(body).to include('$2,520.00')
      expect(body).to include('due on the 24th of each month')
      expect(body).not_to include('[[tuition-plan]]')
      expect(body).not_to include('Option 2') # not a menu of all plans
    end
  end

  describe '{{token}} substitution' do
    it "fills in the family's details when rendering a form" do
      program = create(:program, name: '2026-2027 Nature Preschool', start_date: Date.new(2026, 8, 24), end_date: Date.new(2027, 5, 30))
      enrollment = create(:program_enrollment, child: child, program: program)
      application = create(:enrollment_application, program: program, child: child,
                                                    parent_first_name: 'Dana', parent_last_name: 'Rivera',
                                                    program_enrollment: enrollment)
      template = FormTemplate.find_or_create_by!(key: 'family_agreement') { |t| t.name = 'Family Agreement & Waiver' }
      template.update!(body: "{{child_name}} enrolls in {{program_name}} for {{school_year}}, signed by {{parent_name}}.")
      sig = EnrollmentFormSignature.create!(child: child, form_template: template, enrollment_application: application)

      body = sig.rendered_body
      expect(body).to include(child.full_name)
      expect(body).to include('2026-2027 Nature Preschool')
      expect(body).to include('2026–2027')
      expect(body).to include('Dana Rivera')
      expect(body).not_to include('{{')
    end

    it 'rejects an unknown token when saving a form template' do
      template = FormTemplate.find_or_create_by!(key: 'family_agreement') { |t| t.name = 'Family Agreement & Waiver' }
      template.body = 'Hello {{not_a_real_token}}'
      expect(template).not_to be_valid
      expect(template.errors[:base].join).to include('not_a_real_token')
    end
  end

  describe 'form templates' do
    it 'admins can edit form text' do
      sign_in admin
      get '/api/form_templates'
      template = JSON.parse(response.body)['forms'].first

      patch "/api/form_templates/#{template['id']}", params: {
        form_template: { body: 'Updated waiver text.' }
      }

      expect(response).to have_http_status(:ok)
      expect(FormTemplate.find(template['id']).body).to eq('Updated waiver text.')
    end
  end
end
