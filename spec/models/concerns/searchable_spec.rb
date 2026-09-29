require 'rails_helper'

RSpec.describe Searchable do
  # Family searches its own name plus its parents' and children's names.
  let!(:quillon) do
    create(:family, name: 'Quillon').tap do |family|
      create(:parent, family: family, first_name: 'Zéphyrine', last_name: 'Quillon', email: 'zeph@example.com')
      # Fixed email: a Faker one can contain "_", which the literal-% test searches for.
      create(:parent, family: family, first_name: 'Orsolo', last_name: 'Quillon', email: 'orsolo@example.com')
      create(:child, family: family, first_name: 'Theodric', last_name: 'Quillon')
    end
  end
  let!(:other) { create(:family, name: 'Varnholt') }

  it 'matches any searchable column, ignoring case' do
    expect(Family.search('THEODRIC')).to contain_exactly(quillon)
    expect(Family.search('varnholt')).to contain_exactly(other)
  end

  it 'ignores accents both ways' do
    expect(Family.search('zephyrine')).to contain_exactly(quillon)
    expect(Family.search('Zéphyrine')).to contain_exactly(quillon)
  end

  it 'requires every word, which may match different joined rows' do
    # "orsolo" is one parent and "theodric" a child: two different joined rows.
    expect(Family.search('orsolo theodric')).to contain_exactly(quillon)
    expect(Family.search('orsolo varnholt')).to be_empty
  end

  it 'returns each record once even when several joined rows match' do
    expect(Family.search('quillon').to_a).to eq([quillon])
  end

  it 'treats % and _ literally' do
    expect(Family.search('%')).to be_empty
    expect(Family.search('_')).to be_empty
  end

  it 'returns the scope unchanged for a blank query' do
    expect(Family.search('  ')).to contain_exactly(quillon, other)
  end

  it 'keeps the outer scope, order included' do
    create(:family, name: 'Quillon Annex')
    expect(Family.where.not(id: other.id).order(name: :desc).search('quillon').map(&:name))
      .to eq(['Quillon Annex', 'Quillon'])
  end

  it 'leaves soft-deleted records out' do
    quillon.soft_delete!
    expect(Family.search('theodric')).to be_empty
  end
end
