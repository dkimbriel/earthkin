require 'rails_helper'

# Behavior of the SoftDeletable concern, exercised through Family/Child (a
# cascade parent/child pair) and Program (an independent root).
RSpec.describe SoftDeletable do
  let(:family) { create(:family) }
  let!(:child_a) { create(:child, family: family) }
  let!(:child_b) { create(:child, family: family) }
  let!(:parent) { create(:parent, family: family) }

  describe '#soft_delete!' do
    it 'hides the record and cascades to dependents without destroying rows' do
      family.soft_delete!

      # Hidden from the default scope...
      expect(Family.exists?(family.id)).to be(false)
      expect(Child.where(id: [child_a.id, child_b.id])).to be_empty
      # ...but the rows still exist and are marked deleted.
      expect(Family.with_deleted.find(family.id)).to be_deleted
      expect(Child.with_deleted.find(child_a.id)).to be_deleted
      expect(Parent.with_deleted.find(parent.id)).to be_deleted
    end

    it 'stamps the whole cascade with one shared timestamp' do
      family.soft_delete!
      ts = Family.with_deleted.find(family.id).deleted_at

      expect(Child.with_deleted.find(child_a.id).deleted_at).to eq(ts)
      expect(Parent.with_deleted.find(parent.id).deleted_at).to eq(ts)
    end

    it 'is a no-op on an already-deleted record' do
      family.soft_delete!
      expect { family.soft_delete! }.not_to raise_error
    end
  end

  describe '#restore!' do
    it 'restores the record and the dependents deleted with it' do
      family.soft_delete!
      Family.with_deleted.find(family.id).restore!

      expect(Family.exists?(family.id)).to be(true)
      expect(Child.where(id: [child_a.id, child_b.id]).count).to eq(2)
      expect(Parent.exists?(parent.id)).to be(true)
    end

    it 'does not resurrect a dependent that was deleted separately earlier' do
      child_a.soft_delete!           # deleted on its own, earlier
      family.soft_delete!            # whole family deleted later (child_a already gone)

      Family.with_deleted.find(family.id).restore!

      # child_b came back with the family; child_a stays deleted (different batch).
      expect(Child.exists?(child_b.id)).to be(true)
      expect(Child.exists?(child_a.id)).to be(false)
    end
  end

  describe '#deletion_root?' do
    it 'is true for the directly-deleted record and false for cascade children' do
      family.soft_delete!

      expect(Family.with_deleted.find(family.id).deletion_root?).to be(true)
      expect(Child.with_deleted.find(child_a.id).deletion_root?).to be(false)
    end

    it 'is true for a dependent deleted on its own' do
      child_a.soft_delete!
      expect(Child.with_deleted.find(child_a.id).deletion_root?).to be(true)
    end
  end

  describe 'uniqueness after soft delete' do
    it 'frees a scoped-unique value (e.g. a location name) once deleted' do
      create(:location, name: 'Meadow').soft_delete!
      expect { create(:location, name: 'Meadow') }.not_to raise_error
    end
  end
end
