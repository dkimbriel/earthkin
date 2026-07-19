# frozen_string_literal: true

# Restorable (soft) deletes. Including model gets a `deleted_at` timestamp and a
# default scope that hides deleted rows everywhere (including through
# associations), so the rest of the app keeps working unchanged. Deleting and
# restoring cascade to declared dependents using a shared timestamp, so a
# restore brings back exactly the subtree that was removed together — not
# records that happened to be deleted separately earlier.
#
# Use `soft_delete!` / `restore!` instead of `destroy`. Reach deleted rows with
# the `with_deleted` / `only_deleted` scopes.
module SoftDeletable
  extend ActiveSupport::Concern

  included do
    default_scope { where(deleted_at: nil) }
    scope :with_deleted, -> { unscope(where: :deleted_at) }
    scope :only_deleted, -> { with_deleted.where.not(deleted_at: nil) }
    class_attribute :soft_delete_cascade, instance_writer: false, default: []
  end

  class_methods do
    # Associations to soft-delete alongside this record (mirrors the model's
    # existing dependent: :destroy graph, but soft).
    def cascades_soft_delete(*associations)
      self.soft_delete_cascade = associations.map(&:to_sym)
    end
  end

  def deleted?
    deleted_at.present?
  end

  # Mark this record (and its cascade subtree) deleted, all sharing one
  # timestamp so a later restore can bring back exactly this batch.
  def soft_delete!(timestamp = Time.current)
    return self if deleted?

    self.class.transaction do
      update_column(:deleted_at, timestamp)
      cascade_targets.each { |record| record.soft_delete!(timestamp) }
    end
    self
  end

  # Restore this record and any dependents deleted together with it (same
  # timestamp). Dependents deleted separately keep their own deleted state.
  def restore!
    timestamp = deleted_at
    return self if timestamp.nil?

    self.class.transaction do
      update_column(:deleted_at, nil)
      self.class.soft_delete_cascade.each do |association|
        reflection = self.class.reflect_on_association(association)
        next unless reflection

        reflection.klass.only_deleted
                  .where(reflection.foreign_key => id, deleted_at: timestamp)
                  .each(&:restore!)
      end
    end
    self
  end

  # A deleted record is a "root" deletion when no soft-deletable parent was
  # deleted in the same batch — i.e. it's what the admin deleted directly, not a
  # cascade child. Used to keep the Recently Deleted list uncluttered.
  def deletion_root?
    return false unless deleted?

    self.class.reflect_on_all_associations(:belongs_to).none? do |reflection|
      next false if reflection.polymorphic?

      klass = reflection.klass
      next false unless klass.respond_to?(:only_deleted)

      parent_id = public_send(reflection.foreign_key)
      next false if parent_id.nil?

      parent = klass.with_deleted.find_by(id: parent_id)
      parent&.deleted_at == deleted_at
    end
  end

  # Human label for the Recently Deleted list; override per model.
  def deleted_label
    "#{self.class.model_name.human} #{id}"
  end

  private

  def cascade_targets
    self.class.soft_delete_cascade.flat_map do |association|
      value = public_send(association)
      value.respond_to?(:to_a) ? value.to_a : Array(value)
    end
  end
end
