require 'rails_helper'

RSpec.describe 'Full Program Lifecycle', type: :request do
  let(:user) { create(:user) }
  let(:teacher) { create(:teacher) }
  let(:location) { create(:location) }

  before do
    sign_in user
  end

  it 'manages a complete program lifecycle from creation to enrollment' do
    # Step 1: Create a new program
    post '/api/programs', params: {
      program: {
        name: 'Spring 2027 Forest Explorers',
        description: 'Outdoor nature exploration program',
        start_date: '2027-03-01',
        end_date: '2027-05-31'
      }
    }
    expect(response).to have_http_status(:created)
    program_data = JSON.parse(response.body)
    program_id = program_data['id']

    # Step 2: Create program classes for the program
    post '/api/program_classes', params: {
      program_class: {
        program_id: program_id,
        name: 'Morning Explorers',
        day_of_week: 'Monday',
        start_time: '09:00',
        end_time: '12:00'
      }
    }
    expect(response).to have_http_status(:created)

    post '/api/program_classes', params: {
      program_class: {
        program_id: program_id,
        name: 'Afternoon Adventurers',
        day_of_week: 'Wednesday',
        start_time: '13:00',
        end_time: '16:00'
      }
    }
    expect(response).to have_http_status(:created)

    # Step 3: Create payment plans for the program
    post '/api/payment_plans', params: {
      payment_plan: {
        program_id: program_id,
        name: 'Full Payment',
        description: 'Pay in full',
        installment_count: 1,
        total_amount: 2800.00
      }
    }
    expect(response).to have_http_status(:created)

    post '/api/payment_plans', params: {
      payment_plan: {
        program_id: program_id,
        name: 'Monthly Payments',
        description: '10 monthly installments',
        installment_count: 10,
        total_amount: 2800.00
      }
    }
    expect(response).to have_http_status(:created)

    # Step 4: View the program with all its details
    get "/api/programs/#{program_id}"
    expect(response).to have_http_status(:success)
    program = JSON.parse(response.body)
    expect(program['name']).to eq('Spring 2027 Forest Explorers')

    # Step 5: List program classes for this program
    get '/api/program_classes', params: { program_id: program_id }
    expect(response).to have_http_status(:success)
    classes = JSON.parse(response.body)
    expect(classes.length).to eq(2)

    # Step 6: List payment plans for this program
    get '/api/payment_plans', params: { program_id: program_id, active: 'true' }
    expect(response).to have_http_status(:success)
    plans = JSON.parse(response.body)
    expect(plans.length).to eq(2)

    # Step 7: Create a family and child
    post '/api/families', params: {
      family: { name: 'Anderson Family' }
    }
    expect(response).to have_http_status(:created)
    family_data = JSON.parse(response.body)
    family_id = family_data['id']

    post '/api/parents', params: {
      parent: {
        family_id: family_id,
        first_name: 'Michael',
        last_name: 'Anderson',
        email: 'michael@example.com',
        phone: '(555) 987-6543'
      }
    }
    expect(response).to have_http_status(:created)

    post '/api/children', params: {
      child: {
        family_id: family_id,
        first_name: 'Olivia',
        last_name: 'Anderson'
      }
    }
    expect(response).to have_http_status(:created)
    child_data = JSON.parse(response.body)
    child_id = child_data['id']

    # Step 8: Enroll the child in the program
    post '/api/program_enrollments', params: {
      program_enrollment: {
        program_id: program_id,
        child_id: child_id,
        status: 'active',
        enrollment_date: Date.today
      }
    }
    expect(response).to have_http_status(:created)
    enrollment_data = JSON.parse(response.body)
    enrollment_id = enrollment_data['id']

    # Step 9: Record enrollment fee payment
    post '/api/payments', params: {
      payment: {
        program_enrollment_id: enrollment_id,
        amount: 150.00,
        payment_date: Date.today,
        payment_method: 'venmo',
        status: 'completed',
        payment_type: 'enrollment_fee'
      }
    }
    expect(response).to have_http_status(:created)

    # Step 10: Record first tuition payment
    post '/api/payments', params: {
      payment: {
        program_enrollment_id: enrollment_id,
        amount: 280.00,
        payment_date: Date.today,
        payment_method: 'venmo',
        status: 'completed',
        payment_type: 'tuition'
      }
    }
    expect(response).to have_http_status(:created)
    payment_data = JSON.parse(response.body)
    payment_id = payment_data['id']

    # Step 11: View all payments for this enrollment
    get '/api/payments', params: { program_enrollment_id: enrollment_id }
    expect(response).to have_http_status(:success)
    payments = JSON.parse(response.body)
    expect(payments.length).to eq(2)

    # Step 12: View all enrollments for the program
    get '/api/program_enrollments', params: { program_id: program_id }
    expect(response).to have_http_status(:success)
    enrollments = JSON.parse(response.body)
    expect(enrollments.length).to eq(1)

    # Step 13: Send invoice for a payment
    post "/api/payments/#{payment_id}/send_invoice"
    expect(response).to have_http_status(:ok)

    # Step 14: View the family with all its data
    get "/api/families/#{family_id}"
    expect(response).to have_http_status(:success)
    family = JSON.parse(response.body)
    expect(family['children'].length).to eq(1)
    expect(family['parents'].length).to eq(1)
  end
end
