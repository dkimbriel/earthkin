require 'rails_helper'

# Parents must never be able to read or write other families' data.
# This spec is the regression guard for that guarantee at every layer:
# staff APIs reject parents outright, portal endpoints are scoped to the
# logged-in parent's own family, and id probing cross-family 404s.
RSpec.describe 'Parent data isolation', type: :request do
  let(:my_family) { create(:family, name: 'Mine') }
  let(:parent_user) { create(:user, :parent) }
  let!(:my_parent) { create(:parent, family: my_family, user: parent_user, email: 'me@example.com') }
  let!(:my_child) { create(:child, family: my_family, first_name: 'MyKid') }

  let(:other_family) { create(:family, name: 'Others') }
  let!(:other_parent) { create(:parent, family: other_family, email: 'other@example.com') }
  let!(:other_child) { create(:child, family: other_family, first_name: 'OtherKid') }
  let(:program) { create(:program) }
  let!(:other_enrollment) { create(:program_enrollment, child: other_child, program: program) }
  let!(:other_payment) { create(:payment, program_enrollment: other_enrollment, amount: 500) }

  before { sign_in parent_user }

  describe 'staff collection endpoints all reject parents' do
    STAFF_COLLECTION_ENDPOINTS = %w[
      /api/families
      /api/parents
      /api/children
      /api/programs
      /api/program_classes
      /api/program_enrollments
      /api/payments
      /api/locations
      /api/teachers
      /api/users
      /api/content_items
      /api/emails
      /api/email_templates
      /api/form_templates
      /api/enrollment_form_signatures
      /api/events
      /api/payment_plans
      /api/enrollment_applications
      /api/enrollment_applications/counts
      /api/reports/weekly_revenue
      /api/admin/integrations/gmail
    ].freeze

    STAFF_COLLECTION_ENDPOINTS.each do |endpoint|
      it "403s GET #{endpoint}" do
        get endpoint
        expect(response).to have_http_status(:forbidden), "expected 403 for #{endpoint}, got #{response.status}"
        expect(response.body).not_to include('OtherKid')
        expect(response.body).not_to include('other@example.com')
      end
    end
  end

  describe 'staff record endpoints reject parents probing other families' do
    it '403s direct id lookups' do
      [
        "/api/families/#{other_family.id}",
        "/api/parents/#{other_parent.id}",
        "/api/children/#{other_child.id}",
        "/api/program_enrollments/#{other_enrollment.id}",
        "/api/payments/#{other_payment.id}",
        "/api/enrollment_form_signatures?family_id=#{other_family.id}"
      ].each do |endpoint|
        get endpoint
        expect(response).to have_http_status(:forbidden), "expected 403 for #{endpoint}, got #{response.status}"
        expect(response.body).not_to include('OtherKid')
      end
    end

    it '403s write attempts' do
      post '/api/families', params: { family: { name: 'X' } }
      expect(response).to have_http_status(:forbidden)

      patch "/api/parents/#{other_parent.id}", params: { parent: { email: 'stolen@example.com' } }
      expect(response).to have_http_status(:forbidden)
      expect(other_parent.reload.email).to eq('other@example.com')

      delete "/api/children/#{other_child.id}"
      expect(response).to have_http_status(:forbidden)
      expect(Child.exists?(other_child.id)).to be true

      post "/api/payments/#{other_payment.id}/send_invoice"
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'portal endpoints only ever return the own family' do
    let!(:my_enrollment) { create(:program_enrollment, child: my_child, program: program) }

    it 'overview excludes other families' do
      get '/api/portal/overview'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('MyKid')
      expect(response.body).not_to include('OtherKid')
      expect(response.body).not_to include('other@example.com')
    end

    it 'payments excludes other families' do
      get '/api/portal/payments'

      json = JSON.parse(response.body)
      expect(json.map { |r| r['child_name'] }).to all(include('MyKid'))
      expect(response.body).not_to include('OtherKid')
    end

    it 'forms excludes other families and blocks cross-family signing' do
      sign_out parent_user
      admin = create(:user)
      sign_in admin
      post '/api/enrollment_form_signatures', params: { child_id: my_child.id }
      post '/api/enrollment_form_signatures', params: { child_id: other_child.id }
      sign_out admin
      sign_in parent_user

      get '/api/portal/forms'
      json = JSON.parse(response.body)
      expect(json.map { |f| f['child_name'] }.uniq).to eq([my_child.full_name])
      expect(response.body).not_to include('OtherKid')

      other_signature = other_child.enrollment_form_signatures.first
      post "/api/portal/forms/#{other_signature.id}/sign", params: { signed_by_name: 'Sneaky Parent' }
      expect(response).to have_http_status(:not_found)
      expect(other_signature.reload.status).to eq('pending')
    end
  end

  describe 'public endpoints still work for signed-in parents' do
    it 'allows the public program view' do
      get "/api/public/programs/#{program.id}"
      expect(response).to have_http_status(:ok)
    end

    it 'allows submitting a public enrollment application' do
      post '/api/enrollment_applications', params: {
        enrollment_application: {
          program_id: program.id,
          parent_first_name: 'Me',
          parent_last_name: 'Parent',
          parent_email: 'me@example.com',
          parent_phone: '(555) 123-4567',
          child_first_name: 'Second',
          child_last_name: 'Kid',
          child_date_of_birth: 4.years.ago.to_date.to_s,
          child_description: 'A curious kid who loves the outdoors.',
          why_interested: 'Sibling already enrolled!',
          is_local: 'yes',
          referral_source: 'Word of mouth'
        }
      }
      expect(response).to have_http_status(:created)
    end
  end

  describe 'the public enrollment form cannot mass-assign privileged fields' do
    it 'ignores family_id, child_id, custom fees, and admin_notes on create' do
      post '/api/enrollment_applications', params: {
        enrollment_application: {
          program_id: program.id,
          parent_first_name: 'Me',
          parent_last_name: 'Parent',
          parent_email: 'me@example.com',
          parent_phone: '(555) 123-4567',
          child_first_name: 'Second',
          child_last_name: 'Kid',
          child_date_of_birth: 4.years.ago.to_date.to_s,
          child_description: 'A curious kid who loves the outdoors.',
          why_interested: 'Sibling already enrolled!',
          is_local: 'yes',
          referral_source: 'Word of mouth',
          # Malicious extras that must be ignored:
          family_id: other_family.id,
          child_id: other_child.id,
          custom_enrollment_fee: 0,
          custom_tuition_amount: 1,
          admin_notes: 'VIP - waive everything'
        }
      }

      expect(response).to have_http_status(:created)
      app = EnrollmentApplication.order(:created_at).last
      expect(app.family_id).to be_nil
      expect(app.child_id).to be_nil
      expect(app.custom_enrollment_fee).to be_nil
      expect(app.custom_tuition_amount).to be_nil
      expect(app.admin_notes).to be_nil
    end
  end

  describe 'portal document endpoints reject cross-family ids' do
    it '404s viewing or downloading another family\'s signed form' do
      sign_out parent_user
      admin = create(:user)
      sign_in admin
      post '/api/enrollment_form_signatures', params: { child_id: other_child.id }
      sign_out admin
      sign_in parent_user

      other_signature = other_child.enrollment_form_signatures.first

      post "/api/portal/forms/#{other_signature.id}/view"
      expect(response).to have_http_status(:not_found)

      get "/api/portal/forms/#{other_signature.id}/pdf"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'public token endpoints reject unknown tokens' do
    before { sign_out parent_user }

    it '404s a bogus payment-selection token' do
      get '/payment/not-a-real-token'
      expect(response).to have_http_status(:not_found)
    end

    it '404s a bogus meeting-confirmation token' do
      get '/meetings/not-a-real-token/confirm'
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'anonymous users' do
    before { sign_out parent_user }

    it '401s staff and portal endpoints' do
      get '/api/families'
      expect(response).to have_http_status(:unauthorized)

      get '/api/portal/overview'
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
