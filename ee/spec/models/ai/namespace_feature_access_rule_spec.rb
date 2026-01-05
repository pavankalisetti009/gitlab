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
end
