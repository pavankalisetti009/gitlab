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
  end

  context 'with loose foreign key on security_category.namespace_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:group) }
      let_it_be(:model) { create(:security_category, namespace: parent) }
    end
  end
end
