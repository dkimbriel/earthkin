require 'rails_helper'

RSpec.describe StaffDocument, type: :model do
  let(:teacher) { create(:teacher) }
  let(:admin) { create(:user) }

  describe '.issue!' do
    it 'resolves tokens once and copies the text onto the document' do
      template = FormTemplate.create!(
        key: 'staff_test', name: 'Test Notice', category: 'staff',
        body: "Notice for {{employee_name}} ({{employee_position}}) at {{school_name}}."
      )

      document = described_class.issue!(
        teacher: teacher, issued_by: admin, form_template: template,
        title: 'Test Notice', employee_position: 'Lead Teacher'
      )

      expect(document.body).to include(teacher.full_name)
      expect(document.body).to include('Lead Teacher')
      expect(document.body).not_to include('{{')
      expect(document.status).to eq('pending')
    end

    it 'leaves an issued document alone when the template is later edited' do
      template = FormTemplate.create!(key: 'staff_edit', name: 'Notice', category: 'staff', body: 'Original text.')
      document = described_class.issue!(teacher: teacher, issued_by: admin, form_template: template, title: 'Notice')

      template.update!(body: 'Rewritten text.')

      expect(document.reload.body).to eq('Original text.')
    end

    it 'records an issued event in the audit trail' do
      document = described_class.issue!(teacher: teacher, issued_by: admin, title: 'Notice', body: 'Text.')

      expect(document.audit_log.map { |e| e['event'] }).to eq(['issued'])
    end
  end

  describe 'two-party signing' do
    let(:document) { create(:staff_document, teacher: teacher, issued_by: admin) }

    it 'stays partially signed until both parties have signed' do
      document.sign_as_employee!(name: teacher.full_name, email: teacher.email, ip: '1.2.3.4')
      expect(document.reload.status).to eq('partially_signed')
      expect(document).not_to be_complete

      document.countersign!(name: 'Director', email: admin.email, ip: '5.6.7.8')
      expect(document.reload.status).to eq('signed')
      expect(document).to be_complete
    end

    it 'completes in either order' do
      document.countersign!(name: 'Director')
      expect(document.reload.status).to eq('partially_signed')

      document.sign_as_employee!(name: teacher.full_name)
      expect(document.reload.status).to eq('signed')
    end

    it 'freezes the text at the first signature so both parties sign the same document' do
      document.sign_as_employee!(name: teacher.full_name)
      original = document.reload.signing_text

      document.update!(body: 'Someone edited this afterwards.')

      expect(document.reload.signing_text).to eq(original)
    end

    it 'fingerprints the signed text identically for both signatures' do
      document.sign_as_employee!(name: teacher.full_name)
      document.countersign!(name: 'Director')

      fingerprints = document.reload.audit_log.filter_map { |e| e['document_sha256'] }
      expect(fingerprints.size).to eq(2)
      expect(fingerprints.uniq.size).to eq(1)
    end

    it 'records the employee comments without requiring them' do
      document.sign_as_employee!(name: teacher.full_name, comments: 'I disagree with item 3.')

      expect(document.reload.employee_comments).to eq('I disagree with item 3.')
    end

    it 'refuses a second signature from the same party' do
      document.sign_as_employee!(name: teacher.full_name)

      expect { document.sign_as_employee!(name: teacher.full_name) }
        .to raise_error(ArgumentError, /already signed/)
    end

    it 'refuses a second counter-signature' do
      document.countersign!(name: 'Director')

      expect { document.countersign!(name: 'Director') }
        .to raise_error(ArgumentError, /already been counter-signed/)
    end

    it 'requires a name' do
      expect { document.sign_as_employee!(name: '') }.to raise_error(ArgumentError, /name is required/)
      expect { document.countersign!(name: nil) }.to raise_error(ArgumentError, /name is required/)
    end

    it 'enforces required fields in the document body' do
      document.update!(body: "[[text:reason|Reason*]]\n[[signature]]")

      expect { document.sign_as_employee!(name: teacher.full_name, form_fields: { 'reason' => '' }) }
        .to raise_error(ArgumentError, /Reason/)
    end
  end

  describe 'after the employee record is archived' do
    it 'still resolves the employee and renders, since staff are archived once they leave' do
      document = create(:staff_document, teacher: teacher, issued_by: admin)
      document.sign_as_employee!(name: teacher.full_name)
      document.countersign!(name: 'Director')

      teacher.soft_delete!

      expect(document.reload.as_json[:teacher_name]).to eq(teacher.full_name)
      expect(StaffDocumentPdfGenerator.new(document).render[0, 4]).to eq('%PDF')
    end
  end

  describe 'audit trail' do
    let(:document) { create(:staff_document, teacher: teacher) }

    it 'records views' do
      document.record_view!(email: teacher.email, ip: '1.2.3.4', user_agent: 'rspec')

      entry = document.reload.audit_log.last
      expect(entry['event']).to eq('viewed')
      expect(entry['ip']).to eq('1.2.3.4')
    end
  end
end
