# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Attribute, feature_category: :security_asset_inventories do
  let_it_be(:parent) { create(:group) }

  describe 'associations' do
    it { is_expected.to belong_to(:security_category).required }
    it { is_expected.to belong_to(:namespace).required }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:description) }
    it { is_expected.to validate_presence_of(:editable_state) }
    it { is_expected.to validate_presence_of(:color) }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to validate_length_of(:description).is_at_most(255) }

    context 'when validating uniqueness of name scoped to category' do
      let_it_be(:security_category) { create(:security_category, namespace: parent, name: "validation test") }

      subject { create(:security_attribute, namespace: parent, security_category: security_category) }

      it { is_expected.to validate_uniqueness_of(:name).scoped_to(:security_category_id) }
    end
  end

  describe '#before_validation' do
    it 'strips leading and trailing whitespace from name' do
      attribute = described_class.new(name: '  Test Label  ')
      attribute.valid?
      expect(attribute.name).to eq('Test Label')
    end

    it 'strips leading and trailing whitespace from description' do
      attribute = described_class.new(description: '   Test description   ')
      attribute.valid?
      expect(attribute.description).to eq('Test description')
    end
  end

  describe 'scopes' do
    let(:category) { create(:security_category, namespace: parent, name: 'Category') }
    let!(:active_attribute) do
      create(:security_attribute, security_category: category, namespace: parent, name: 'Active')
    end

    let!(:deleted_attribute) do
      create(:security_attribute, security_category: category, namespace: parent, name: 'Deleted',
        deleted_at: Time.current)
    end

    describe '.not_deleted' do
      it 'returns only attributes without deleted_at' do
        expect(described_class.not_deleted).to contain_exactly(active_attribute)
      end
    end

    describe '.deleted' do
      it 'returns only attributes with deleted_at' do
        expect(described_class.deleted).to contain_exactly(deleted_attribute)
      end
    end

    describe '.by_category' do
      let(:category1) { create(:security_category, namespace: parent, name: 'Category 1') }
      let(:category2) { create(:security_category, namespace: parent, name: 'Category 2') }
      let!(:attribute1) { create(:security_attribute, security_category: category1, namespace: parent, name: 'Attr 1') }
      let!(:attribute2) { create(:security_attribute, security_category: category2, namespace: parent, name: 'Attr 2') }

      it 'returns only attributes from the specified category' do
        result = described_class.by_category(category1)

        expect(result).to include(attribute1)
        expect(result).not_to include(attribute2)
        expect(result.count).to eq(1)
      end
    end
  end

  describe '#destroy' do
    let(:category) { create(:security_category, namespace: parent, name: 'Category') }
    let!(:attribute) { create(:security_attribute, security_category: category, namespace: parent, name: 'Test') }

    it 'soft deletes the attribute by setting deleted_at' do
      expect { attribute.destroy! }.not_to change { described_class.unscoped.count }

      expect(attribute.reload.deleted_at).to be_present
      expect(attribute.deleted?).to be true
    end

    it 'removes the attribute from not_deleted scope' do
      attribute.destroy!

      expect(described_class.not_deleted.where(id: attribute.id)).to be_empty
      expect(described_class.unscoped.where(id: attribute.id)).to exist
    end
  end

  describe '#really_destroy!' do
    let(:category) { create(:security_category, namespace: parent, name: 'Category') }
    let!(:attribute) do
      create(:security_attribute, security_category: category, namespace: parent, name: 'Test',
        deleted_at: Time.current)
    end

    it 'permanently deletes the attribute from database' do
      expect { attribute.really_destroy! }.to change { described_class.unscoped.count }.by(-1)

      expect(described_class.unscoped.where(id: attribute.id)).to be_empty
    end
  end

  describe '.really_destroy_all!' do
    let(:category) { create(:security_category, namespace: parent, name: 'Category') }

    it 'permanently deletes multiple attributes from database' do
      attr1 = create(:security_attribute, security_category: category, namespace: parent, name: 'Test1',
        deleted_at: Time.current)
      attr2 = create(:security_attribute, security_category: category, namespace: parent, name: 'Test2',
        deleted_at: Time.current)
      attr3 = create(:security_attribute, security_category: category, namespace: parent, name: 'Test3',
        deleted_at: Time.current)

      expect { described_class.really_destroy_all!([attr1.id, attr2.id, attr3.id]) }
        .to change { described_class.unscoped.count }.by(-3)

      expect(described_class.unscoped.where(id: [attr1.id, attr2.id, attr3.id])).to be_empty
    end

    it 'returns 0 when ids is nil' do
      expect(described_class.really_destroy_all!(nil)).to eq(0)
    end

    it 'returns 0 when ids is empty array' do
      expect(described_class.really_destroy_all!([])).to eq(0)
    end

    it 'only deletes specified attributes' do
      attr1 = create(:security_attribute, security_category: category, namespace: parent, name: 'Test1',
        deleted_at: Time.current)
      attr2 = create(:security_attribute, security_category: category, namespace: parent, name: 'Test2',
        deleted_at: Time.current)
      attr3 = create(:security_attribute, security_category: category, namespace: parent, name: 'Test3',
        deleted_at: Time.current)

      expect { described_class.really_destroy_all!([attr1.id]) }
        .to change { described_class.unscoped.count }.by(-1)

      expect(described_class.unscoped.where(id: attr1.id)).to be_empty
      expect(described_class.unscoped.where(id: [attr2.id, attr3.id])).to exist
    end
  end

  describe '#deleted?' do
    let(:category) { create(:security_category, namespace: parent, name: 'Category') }

    it 'returns true when deleted_at is present' do
      attribute = create(:security_attribute, security_category: category, namespace: parent, deleted_at: Time.current)
      expect(attribute.deleted?).to be true
    end

    it 'returns false when deleted_at is nil' do
      attribute = create(:security_attribute, security_category: category, namespace: parent)
      expect(attribute.deleted?).to be false
    end
  end

  describe '#editable?' do
    it 'returns true when editable_state is not locked' do
      attribute = build(:security_attribute, editable_state: 'editable')
      expect(attribute.editable?).to be true
    end

    it 'returns false when editable_state is locked' do
      attribute = build(:security_attribute, editable_state: 'locked')
      expect(attribute.editable?).to be false
    end
  end

  context 'with loose foreign key on security_attribute.namespace_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:security_category) { create(:security_category, namespace: parent, name: "lfk test") }
      let_it_be(:model) { create(:security_attribute, namespace: parent, security_category: security_category) }
    end
  end
end
