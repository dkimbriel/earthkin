class Family < ApplicationRecord
  include SoftDeletable
  include Searchable

  searchable 'families.name', 'parents.first_name', 'parents.last_name', 'parents.email',
             'children.first_name', 'children.last_name',
             joins: %i[parents children]

  has_many :parents, dependent: :destroy
  has_many :children, dependent: :destroy
  has_many :enrollment_applications, dependent: :nullify

  cascades_soft_delete :parents, :children

  validates :name, presence: true

  def full_name
    "#{name} Family"
  end

  def deleted_label
    full_name
  end

  def primary_parent
    parents.order(:created_at).first
  end

  # Every email sent to this family, wherever it was logged: on any of its
  # applications (all programs and years), on a parent, or on a payment for
  # one of its children. Drafts are excluded since they were never sent.
  def emails
    application_ids = EnrollmentApplication.where(family_id: id)
                                           .or(EnrollmentApplication.where(child_id: children.select(:id)))
                                           .select(:id)
    payment_ids = Payment.joins(program_enrollment: :child).where(children: { family_id: id }).select(:id)

    Email.where(emailable_type: 'EnrollmentApplication', emailable_id: application_ids)
         .or(Email.where(emailable_type: 'Parent', emailable_id: parents.select(:id)))
         .or(Email.where(emailable_type: 'Payment', emailable_id: payment_ids))
         .where.not(status: 'draft')
         .order(Arel.sql('COALESCE(sent_at, created_at) DESC'))
  end
end
