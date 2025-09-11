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
