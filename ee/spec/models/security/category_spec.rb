# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Category, feature_category: :security_asset_inventories do
  let_it_be(:root_level_group) { create(:group) }

  describe 'associations' do
    it { is_expected.to belong_to(:namespace).required }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to validate_presence_of(:editable_state) }
    it { is_expected.to validate_inclusion_of(:multiple_selection).in_array([true, false]) }
    it { is_expected.to validate_length_of(:description).is_at_most(255) }

    context 'when validating uniqueness of name scoped to root namespace' do
      subject { create(:security_category, namespace: root_level_group) }

      it { is_expected.to validate_uniqueness_of(:name).scoped_to(:namespace_id) }
    end

    describe '#valid_namespace' do
      let_it_be(:subgroup) { create(:group, parent: root_level_group) }
      let_it_be(:project_namespace) { create(:project_namespace) }

      it 'is valid for root group namespace' do
        expect(build(:security_category, namespace: root_level_group)).to be_valid
      end

      it 'is invalid for non-root namespaces' do
        [subgroup, project_namespace].each do |invalid_namespace|
          category = build(:security_category, namespace: invalid_namespace)

          expect(category).not_to be_valid
          expect(category.errors[:namespace]).to include('must be a root group.')
        end
      end
    end

    describe '#strip_whitespaces' do
      it 'strips whitespace from name and description' do
        category = build(:security_category, namespace: root_level_group, name: "  Category with whitespace  ",
          description: "  Description with whitespace  ")

        category.valid?

        expect(category.name).to eq("Category with whitespace")
        expect(category.description).to eq("Description with whitespace")
      end
    end

    describe '#attributes_limit' do
      let(:category) { create(:security_category, namespace: root_level_group) }

      it 'allows up to MAX_ATTRIBUTES security attributes' do
        create_list(:security_attribute, Security::Category::MAX_ATTRIBUTES - 1, security_category: category,
          namespace: root_level_group)

        category.security_attributes <<
          build(:security_attribute, security_category: category, namespace: root_level_group, name: "added 50")
        expect(category).to be_valid
      end

      it 'prevents having more than MAX_ATTRIBUTES security attributes' do
        create_list(:security_attribute, Security::Category::MAX_ATTRIBUTES, security_category: category,
          namespace: root_level_group)

        category.security_attributes <<
          build(:security_attribute, security_category: category, namespace: root_level_group, name: "added 51")

        expect(category).not_to be_valid
        expect(category.errors[:security_attributes]).to include('cannot have more than 50 attributes per category')
      end
    end
  end

  describe 'scopes' do
    describe '.by_namespace' do
      let(:another_root_level_group) { create(:group) }
      let(:category) { create(:security_category, namespace: root_level_group) }
      let(:another_category) { create(:security_category, namespace: another_root_level_group) }

      it 'returns the correct categories' do
        expect(described_class.by_namespace(root_level_group)).to match_array([category])
      end
    end

    describe '.by_namespace_and_template_type' do
      let(:category1) do
        create(:security_category, namespace: root_level_group, template_type: :business_unit, name: "1")
      end

      let(:category2) do
        create(:security_category, namespace: root_level_group, template_type: :application, name: "2")
      end

      it 'returns the correct category' do
        expect(described_class.by_namespace_and_template_type(root_level_group, :application)).to match_array(category2)
      end
    end
  end

  context 'with loose foreign key on security_category.namespace_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:group) }
      let_it_be(:model) { create(:security_category, namespace: parent) }
    end
  end
end
