require 'rails_helper'

# Server-side search (?q=) and pagination (?page=, ?per_page=) on the admin
# list endpoints, all served through PaginatedList#render_list.
RSpec.describe 'List search and pagination', type: :request do
  let(:admin) { create(:user) }

  before { sign_in admin }

  def json
    JSON.parse(response.body)
  end

  describe 'PaginatedList' do
    before { %w[Aldermoor Brackwell Corriden].each { |name| create(:location, name: name) } }

    it 'returns the plain array when no page is requested' do
      get '/api/locations'
      expect(json).to be_an(Array)
      expect(json.map { |l| l['name'] }).to eq(%w[Aldermoor Brackwell Corriden])
    end

    it 'pages the results and reports totals' do
      get '/api/locations', params: { page: 2, per_page: 2 }

      expect(json['data'].map { |l| l['name'] }).to eq(%w[Corriden])
      expect(json['meta']).to eq('page' => 2, 'per_page' => 2, 'total' => 3, 'total_pages' => 2)
    end

    it 'clamps an out-of-range page to the last one' do
      get '/api/locations', params: { page: 9, per_page: 2 }
      expect(json['meta']['page']).to eq(2)
    end

    it 'defaults and caps per_page' do
      get '/api/locations', params: { page: 1 }
      expect(json['meta']['per_page']).to eq(PaginatedList::DEFAULT_PER_PAGE)

      get '/api/locations', params: { page: 1, per_page: 5000 }
      expect(json['meta']['per_page']).to eq(PaginatedList::MAX_PER_PAGE)
    end

    it 'searches before paging, so totals are for the matches' do
      get '/api/locations', params: { q: 'brack', page: 1 }

      expect(json['data'].map { |l| l['name'] }).to eq(%w[Brackwell])
      expect(json['meta']['total']).to eq(1)
    end

    it 'searches without paging too' do
      get '/api/locations', params: { q: 'corriden' }
      expect(json.map { |l| l['name'] }).to eq(%w[Corriden])
    end
  end

  describe 'each list endpoint' do
    def names(key)
      json['data'].map { |row| row[key] }
    end

    it 'enrollment applications: by child, parent email, program, or status, within a status filter' do
      program = create(:program, name: 'Wrenfield Forest School')
      hit = create(:enrollment_application, program: program, child_first_name: 'Ysolde',
                                            parent_email: 'marrow@example.com', status: 'fee_requested')
      create(:enrollment_application, status: 'fee_requested')

      [['ysolde', {}], ['marrow@example', {}], ['wrenfield', {}], ['fee requested wrenfield', {}],
       ['ysolde', { status: 'fee_requested' }]].each do |q, filters|
        get '/api/enrollment_applications', params: { q: q, page: 1 }.merge(filters)
        expect(json['data'].map { |a| a['id'] }).to eq([hit.id]), "q=#{q.inspect}"
      end

      get '/api/enrollment_applications', params: { q: 'ysolde', status: 'enrolled', page: 1 }
      expect(json['data']).to be_empty
    end

    it 'families: by a child name' do
      family = create(:family, name: 'Pellingham')
      create(:child, family: family, first_name: 'Ormund')
      create(:family, name: 'Other')

      get '/api/families', params: { q: 'ormund', page: 1 }
      expect(names('name')).to eq(%w[Pellingham])
    end

    it 'programs: by name' do
      create(:program, name: 'Brackenridge Spring Session')
      create(:program, name: 'Other Program')

      get '/api/programs', params: { q: 'brackenridge', page: 1 }
      expect(names('name')).to eq(['Brackenridge Spring Session'])
    end

    it 'teachers: by email' do
      create(:teacher, first_name: 'Ansel', email: 'ansel.voss@example.com')
      create(:teacher)

      get '/api/teachers', params: { q: 'ansel.voss', page: 1 }
      expect(names('email')).to eq(['ansel.voss@example.com'])
    end

    it 'content: by an assigned teacher, still limited to what the viewer may see' do
      teacher = create(:teacher, first_name: 'Maudrey')
      shared = create(:content_item, title: 'Field Guide', visibility: 'all_staff')
      shared.teachers << teacher
      hidden = create(:content_item, :specific, title: 'Private Handbook')
      hidden.teachers << teacher

      get '/api/content_items', params: { q: 'maudrey', page: 1 }
      expect(names('title')).to contain_exactly('Field Guide', 'Private Handbook')

      viewer = create(:teacher)
      sign_in create(:user, :teacher, teacher: viewer)
      get '/api/content_items', params: { q: 'maudrey', page: 1 }
      expect(names('title')).to eq(['Field Guide'])
    end

    it "staff documents: by teacher name, waiting-on-you first, and only the teacher's own for teachers" do
      teacher = create(:teacher, first_name: 'Corvina')
      signed = create(:staff_document, teacher: teacher, title: 'Warning A', director_signed_at: 2.days.ago)
      waiting = create(:staff_document, teacher: teacher, title: 'Warning B')
      create(:staff_document, title: 'Someone else')

      get '/api/staff_documents', params: { q: 'corvina', page: 1 }
      expect(json['data'].map { |d| d['id'] }).to eq([waiting.id, signed.id])

      other_teacher_user = create(:user, :teacher, teacher: create(:teacher))
      sign_in other_teacher_user
      get '/api/staff_documents', params: { q: 'corvina', page: 1 }
      expect(json['data']).to be_empty
    end

    it "users: by the linked teacher's name" do
      create(:user, :teacher, email: 'quinta@example.com', teacher: create(:teacher, first_name: 'Quintavia'))

      get '/api/users', params: { q: 'quintavia', page: 1 }
      expect(names('email')).to eq(['quinta@example.com'])
    end
  end
end
