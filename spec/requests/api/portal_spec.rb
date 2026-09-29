require 'rails_helper'

RSpec.describe 'Api::Portal', type: :request do
  let(:family) { create(:family) }
  let(:parent_user) { create(:user, :parent) }
  let!(:parent) { create(:parent, family: family, user: parent_user) }
  let!(:child) { create(:child, family: family) }
  let(:program) { create(:program) }
  let!(:enrollment) { create(:program_enrollment, child: child, program: program) }

  describe 'authorization' do
    it 'forbids staff users' do
      sign_in create(:user)

      get '/api/portal/overview'

      expect(response).to have_http_status(:forbidden)
    end

    it 'forbids parent users with no parent record' do
      sign_in create(:user, :parent)

      get '/api/portal/overview'

      expect(response).to have_http_status(:forbidden)
    end

    it 'requires login' do
      get '/api/portal/overview'

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /api/portal/overview' do
    before { sign_in parent_user }

    it 'returns the family, parents and children with enrollments' do
      get '/api/portal/overview'

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['family']['name']).to eq(family.name)
      expect(json['parents'].first['email']).to eq(parent.email)
      expect(json['children'].first['name']).to eq(child.full_name)
      expect(json['children'].first['enrollments'].first['program_name']).to eq(program.name)
    end

    it 'does not include other families' do
      other_family = create(:family)
      create(:child, family: other_family, first_name: 'Other', last_name: 'Kid')

      get '/api/portal/overview'

      json = JSON.parse(response.body)
      expect(json['children'].map { |c| c['name'] }).not_to include('Other Kid')
    end
  end

  describe 'GET /api/portal/events' do
    before { sign_in parent_user }

    it 'returns published school events and enrolled class dates' do
      create(:event, eventable: nil, event_type: 'open_house', title: 'Open House',
                     scheduled_at: 1.week.from_now, published: true)
      create(:event, eventable: nil, event_type: 'other', title: 'Internal Only',
                     scheduled_at: 1.week.from_now, published: false)
      create(:program_class, program: program, name: 'Week 1', date: 2.weeks.from_now.to_date)

      get '/api/portal/events'

      json = JSON.parse(response.body)
      expect(json['events'].map { |e| e['title'] }).to eq(['Open House'])
      expect(json['classes'].first['title']).to include('Week 1')
    end
  end

  describe 'GET /api/portal/payments' do
    before { sign_in parent_user }

    it 'returns enrollment payment info for the family' do
      create(:payment, program_enrollment: enrollment, amount: 100, status: 'completed')

      get '/api/portal/payments'

      json = JSON.parse(response.body)
      expect(json.first['child_name']).to eq(child.full_name)
      expect(json.first['payments'].first['amount']).to eq('100.0')
    end

    it 'exposes the stripe receipt url on completed payments' do
      create(:payment, :stripe, program_enrollment: enrollment, amount: 100)

      get '/api/portal/payments'

      json = JSON.parse(response.body)
      expect(json.first['payments'].first['receipt_url']).to eq('https://pay.stripe.com/receipts/test_123')
    end
  end

  describe 'POST /api/portal/payments/checkout' do
    let!(:plan) { create(:enrollment_payment_plan, :with_monthly_plan, program_enrollment: enrollment) }

    before { sign_in parent_user }

    it 'returns a Stripe Checkout url for a pending installment' do
      expect(StripeCheckout).to receive(:installment_session)
        .with(an_instance_of(EnrollmentPaymentPlan), 0)
        .and_return(double(url: 'https://checkout.stripe.com/c/pay/cs_1'))

      post '/api/portal/payments/checkout',
           params: { enrollment_payment_plan_id: plan.id, installment_index: 0 }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['url']).to eq('https://checkout.stripe.com/c/pay/cs_1')
    end

    it "404s for a plan that isn't the family's" do
      other_plan = create(:enrollment_payment_plan, :with_monthly_plan)

      post '/api/portal/payments/checkout',
           params: { enrollment_payment_plan_id: other_plan.id, installment_index: 0 }

      expect(response).to have_http_status(:not_found)
    end

    it 'rejects an already-completed installment' do
      plan.mark_installment_paid!(0, create(:payment, program_enrollment: enrollment))

      post '/api/portal/payments/checkout',
           params: { enrollment_payment_plan_id: plan.id, installment_index: 0 }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'autopay' do
    let!(:plan) { create(:enrollment_payment_plan, :with_monthly_plan, program_enrollment: enrollment) }

    before { sign_in parent_user }

    it 'shows each plan autopay status and the terms to agree to' do
      get '/api/portal/payments'
      row = JSON.parse(response.body).first

      expect(row.dig('plan', 'autopay', 'enabled')).to be(false)
      expect(row.dig('plan', 'autopay_terms')).to include('I authorize Earthkin Nature School')
    end

    it 'starts a setup session once the parent agrees to the terms' do
      expect(StripeAutopay).to receive(:setup_session)
        .with(an_instance_of(EnrollmentPaymentPlan), parent_email: parent.email)
        .and_return(double(url: 'https://checkout.stripe.com/c/setup/cs_1'))

      post '/api/portal/autopay/setup', params: { enrollment_payment_plan_id: plan.id, consent: true }

      expect(JSON.parse(response.body)['url']).to eq('https://checkout.stripe.com/c/setup/cs_1')
    end

    it 'refuses without consent' do
      expect(StripeAutopay).not_to receive(:setup_session)
      post '/api/portal/autopay/setup', params: { enrollment_payment_plan_id: plan.id }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "can't touch another family's plan" do
      other = create(:enrollment_payment_plan, :with_monthly_plan)
      other.enable_autopay!(method: { id: 'pm_x', type: 'card', label: 'Visa ending 1111' }, enabled_by: 'x@example.com')

      post '/api/portal/autopay/setup', params: { enrollment_payment_plan_id: other.id, consent: true }
      expect(response).to have_http_status(:not_found)

      post '/api/portal/autopay/disable', params: { enrollment_payment_plan_id: other.id }
      expect(response).to have_http_status(:not_found)
      expect(other.reload).to be_autopay
    end

    it 'turns autopay off' do
      plan.enable_autopay!(method: { id: 'pm_1', type: 'card', label: 'Visa ending 4242' }, enabled_by: parent.email)

      post '/api/portal/autopay/disable', params: { enrollment_payment_plan_id: plan.id }

      expect(JSON.parse(response.body).dig('autopay', 'enabled')).to be(false)
      expect(plan.reload).not_to be_autopay
    end
  end
end
