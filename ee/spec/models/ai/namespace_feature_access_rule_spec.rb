# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::NamespaceFeatureAccessRule, feature_category: :ai_abstraction_layer do
  let_it_be(:root_namespace) { create(:group) }
  let_it_be(:through_namespace) { create(:group, parent: root_namespace) }
  let_it_be(:other_root_namespace) { create(:group) }

  it_behaves_like 'accessible entity ruleable'

  describe 'associations' do
    it { is_expected.to belong_to(:through_namespace).inverse_of(:ai_feature_rules_through_namespace) }

    it 'belongs to root namespace' do
      is_expected.to belong_to(:root_namespace)
                       .class_name('Namespace')
                       .inverse_of(:ai_feature_rules)
    end
  end

  describe 'validations' do
    subject { described_class.new(through_namespace: through_namespace, root_namespace: root_namespace) }

    it { is_expected.to validate_presence_of(:root_namespace_id) }

    describe '#through_namespace_root_is_root_namespace validation' do
      context 'when through_namespace root is the same as root_namespace' do
        it 'is valid' do
          rule = build(:ai_namespace_feature_access_rules,
            through_namespace: through_namespace,
            root_namespace: root_namespace)

          expect(rule).to be_valid
        end
      end

      context 'when through_namespace root is different from root_namespace' do
        it 'is invalid' do
          rule = build(:ai_namespace_feature_access_rules,
            through_namespace: through_namespace,
            root_namespace: other_root_namespace
          )

          expect(rule).not_to be_valid
          expect(rule.errors[:through_namespace]).to include(
            'must belong to the same root namespace as the root_namespace'
          )
        end
      end
    end
  end

  describe 'bulk insert' do
    let(:through_namespace1) { create(:group, parent: root_namespace) }
    let(:through_namespace2) { create(:group, parent: root_namespace) }

    it 'bulk inserts multiple records' do
      records = [
        build(:ai_namespace_feature_access_rules,
          :duo_classic,
          through_namespace: through_namespace1,
          root_namespace: root_namespace
        ),
        build(:ai_namespace_feature_access_rules,
          :duo_agent_platform,
          through_namespace: through_namespace2,
          root_namespace: root_namespace
        )
      ]

      expect { described_class.bulk_insert!(records) }.to change { described_class.count }.by(2)
    end
  end

  describe '.by_root_namespace_group_by_through_namespace' do
    let_it_be(:root_namespace1) { create(:group) }
    let_it_be(:root_namespace2) { create(:group) }
    let_it_be(:subgroup1) { create(:group, parent: root_namespace1) }
    let_it_be(:subgroup2) { create(:group, parent: root_namespace1) }
    let_it_be(:subgroup3) { create(:group, parent: root_namespace2) }

    before do
      create(:ai_namespace_feature_access_rules,
        :duo_classic,
        through_namespace: subgroup1,
        root_namespace: root_namespace1
      )
      create(:ai_namespace_feature_access_rules,
        :duo_classic,
        through_namespace: subgroup2,
        root_namespace: root_namespace1
      )
      create(:ai_namespace_feature_access_rules,
        :duo_agent_platform,
        through_namespace: subgroup2,
        root_namespace: root_namespace1
      )
      create(:ai_namespace_feature_access_rules,
        :duo_agent_platform,
        through_namespace: subgroup3,
        root_namespace: root_namespace2
      )
    end

    subject(:result) { described_class.by_root_namespace_group_by_through_namespace(root_namespace1) }

    it 'filters groups by root namespace and groups by through_namespace_id' do
      expect(result.keys).to contain_exactly(subgroup1.id, subgroup2.id)

      expect(result[subgroup1.id]).to contain_exactly(
        have_attributes(
          accessible_entity: 'duo_classic',
          through_namespace_id: subgroup1.id,
          root_namespace_id: root_namespace1.id
        )
      )

      expect(result[subgroup2.id]).to contain_exactly(
        have_attributes(
          accessible_entity: 'duo_classic',
          through_namespace_id: subgroup2.id,
          root_namespace_id: root_namespace1.id
        ),
        have_attributes(
          accessible_entity: 'duo_agent_platform',
          through_namespace_id: subgroup2.id,
          root_namespace_id: root_namespace1.id
        )
      )
    end
  end

  describe '.group_by_through_namespace' do
    let_it_be(:other_through_namespace) { create(:group, parent: root_namespace) }

    before do
      create(:ai_namespace_feature_access_rules,
        :duo_classic,
        through_namespace: through_namespace,
        root_namespace: root_namespace
      )
      create(:ai_namespace_feature_access_rules,
        :duo_agent_platform,
        through_namespace: other_through_namespace,
        root_namespace: root_namespace
      )
    end

    it 'groups rules by through_namespace_id' do
      result = described_class.group_by_through_namespace

      expect(result.keys).to contain_exactly(through_namespace.id, other_through_namespace.id)
      expect(result[through_namespace.id].map(&:accessible_entity)).to contain_exactly('duo_classic')
      expect(result[other_through_namespace.id].map(&:accessible_entity)).to contain_exactly('duo_agent_platform')
    end
  end
end
