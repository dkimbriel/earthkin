require 'rails_helper'

RSpec.describe 'Complete School Operations', type: :request do
  let(:user) { create(:user) }
  let(:program) { create(:program, name: 'Forest Explorers 2027', start_date: '2027-09-01', end_date: '2028-05-31') }
  let(:location1) { create(:location, name: 'Forest Hill Park') }
  let(:location2) { create(:location, name: 'Bryan Park') }
  let(:teacher1) { create(:teacher, first_name: 'Jane', last_name: 'Smith') }
  let(:teacher2) { create(:teacher, first_name: 'John', last_name: 'Doe') }

  before do
    sign_in user
  end

  it 'handles a complete school year setup and enrollment process' do
    # === PROGRAM SETUP ===

    # Create payment plans for the program
    plans = []
    ['Full Payment', 'Semester', 'Quarterly', 'Monthly'].each_with_index do |plan_name, idx|
      post '/api/payment_plans', params: {
        payment_plan: {
          program_id: program.id,
          name: plan_name,
          description: "#{plan_name} option",
          installment_count: idx == 0 ? 1 : (idx + 1) * 2,
          total_amount: 2800.00,
          display_order: idx + 1
        }
      }
      expect(response).to have_http_status(:created)
      plans << JSON.parse(response.body)
    end

    # Create multiple program classes
    ['Monday Morning', 'Wednesday Afternoon', 'Friday Morning'].each_with_index do |class_name, idx|
      post '/api/program_classes', params: {
        program_class: {
          program_id: program.id,
          name: class_name,
          date: (idx + 1).weeks.from_now.to_date
        }
      }
      expect(response).to have_http_status(:created)
    end

    # === FAMILY ENROLLMENTS ===

    3.times do |i|
      # Create family
      post '/api/families', params: {
        family: { name: "Family #{i + 1}" }
      }
      family_data = JSON.parse(response.body)
      family_id = family_data['id']

      # Add parents
      2.times do |j|
        post '/api/parents', params: {
          parent: {
            family_id: family_id,
            first_name: Faker::Name.first_name,
            last_name: "Family#{i + 1}",
            email: "parent#{j + 1}family#{i + 1}@example.com",
            phone: "(555) #{100 + i}#{j}-#{1000 + rand(9000)}"
          }
        }
        expect(response).to have_http_status(:created)
      end

      # Add children
      (i + 1).times do |k|
        post '/api/children', params: {
          child: {
            family_id: family_id,
            first_name: Faker::Name.first_name,
            last_name: "Family#{i + 1}"
          }
        }
        child_data = JSON.parse(response.body)

        # Enroll child in program
        post '/api/program_enrollments', params: {
          program_enrollment: {
            program_id: program.id,
            child_id: child_data['id'],
            status: 'confirmed',
            enrollment_date: Date.today
          }
        }
        enrollment_data = JSON.parse(response.body)

        # Create payment plan for enrollment
        selected_plan = plans.sample
        post '/api/enrollment_payment_plans', params: {
          enrollment_payment_plan: {
            program_enrollment_id: enrollment_data['id'],
            payment_plan_id: selected_plan['id'],
            total_amount: 2800.00,
            enrollment_fee: 150.00
          }
        }
        plan_data = JSON.parse(response.body)

        # Record enrollment fee
        post "/api/enrollment_payment_plans/#{plan_data['id']}/record_enrollment_fee", params: {
          payment_method: 'venmo',
          payment_date: Date.today.to_s,
          notes: 'Enrollment fee paid'
        }
        expect(response).to have_http_status(:success)
      end
    end

    # === VERIFICATION ===

    # Verify families were created
    get '/api/families'
    families = JSON.parse(response.body)
    expect(families.length).to eq(3)

    # Verify parents were created
    get '/api/parents'
    parents = JSON.parse(response.body)
    expect(parents.length).to eq(6) # 2 parents per family × 3 families

    # Verify children were enrolled
    get '/api/program_enrollments', params: { program_id: program.id }
    enrollments = JSON.parse(response.body)
    expected_enrollments = 1 + 2 + 3 # Family 1: 1 child, Family 2: 2 children, Family 3: 3 children
    expect(enrollments.length).to eq(expected_enrollments)

    # Verify payments were recorded
    get '/api/payments'
    payments = JSON.parse(response.body)
    expect(payments.length).to be >= expected_enrollments # At least enrollment fees

    # Verify payment plans
    get '/api/payment_plans', params: { program_id: program.id }
    payment_plans = JSON.parse(response.body)
    expect(payment_plans.length).to eq(4)

    # Verify program classes
    get '/api/program_classes', params: { program_id: program.id }
    classes = JSON.parse(response.body)
    expect(classes.length).to eq(3)

    # === ADDITIONAL OPERATIONS ===

    # View a specific family with all details
    first_family = families.first
    get "/api/families/#{first_family['id']}"
    family_details = JSON.parse(response.body)
    expect(family_details).to have_key('parents')
    expect(family_details).to have_key('children')

    # View program details
    get "/api/programs/#{program.id}"
    program_details = JSON.parse(response.body)
    expect(program_details['name']).to eq('Forest Explorers 2027')

    # Update a program
    patch "/api/programs/#{program.id}", params: {
      program: { description: 'Updated description' }
    }
    expect(response).to have_http_status(:success)

    # View all locations
    create_list(:location, 2)
    get '/api/locations'
    locations = JSON.parse(response.body)
    expect(locations.length).to be >= 2

    # View all teachers
    create_list(:teacher, 2)
    get '/api/teachers'
    teachers = JSON.parse(response.body)
    expect(teachers.length).to be >= 2
  end
end
