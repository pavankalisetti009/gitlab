# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::FeatureAccessRule, feature_category: :ai_abstraction_layer do
  let_it_be(:through_namespace) { create(:group) }

  include_examples 'accessible entity ruleable'

  describe 'associations' do
    it { is_expected.to belong_to(:through_namespace).inverse_of(:accessible_ai_features_on_instance) }
  end

  describe 'bulk insert' do
    let_it_be(:namespace1) { create(:group) }
    let_it_be(:namespace2) { create(:group) }

    it 'bulk inserts multiple records' do
      records = [
        build(:ai_instance_accessible_entity_rules,
          :duo_classic,
          through_namespace: namespace1
        ),
        build(:ai_instance_accessible_entity_rules,
          :duo_agents,
          through_namespace: namespace2
        )
      ]

      expect { described_class.bulk_insert!(records) }.to change { described_class.count }.by(2)
    end
  end

  describe '.duo_namespace_access_rules' do
    let_it_be(:namespace_a) { create(:group) }
    let_it_be(:namespace_b) { create(:group) }

    before do
      stub_feature_flags(duo_access_through_namespaces: true)
    end

    context 'when rules exist' do
      before do
        create(:ai_instance_accessible_entity_rules, :duo_classic, through_namespace_id: namespace_a.id)
        create(:ai_instance_accessible_entity_rules, :duo_agents, through_namespace_id: namespace_a.id)
        create(:ai_instance_accessible_entity_rules, :duo_flows, through_namespace_id: namespace_b.id)
      end

      it 'returns rules' do
        expect(described_class.duo_namespace_access_rules).to match_array([
          {
            namespace_id: namespace_a.id,
            namespace_name: namespace_a.name,
            namespace_path: namespace_a.full_path,
            access_rules: %w[duo_classic duo_agents]
          },
          {
            namespace_id: namespace_b.id,
            namespace_name: namespace_b.name,
            namespace_path: namespace_b.full_path,
            access_rules: %w[duo_flows]
          }
        ])
      end
    end

    context 'when no rules exist' do
      it 'returns empty array' do
        expect(described_class.duo_namespace_access_rules).to eq []
      end
    end

    context 'when duo_access_through_namespaces feature flag is disabled' do
      before do
        stub_feature_flags(duo_access_through_namespaces: false)
      end

      it 'returns empty array' do
        expect(described_class.duo_namespace_access_rules).to eq []
      end
    end
  end

  describe '.duo_namespace_access_rules=' do
    let_it_be(:namespace_a) { create(:group) }
    let_it_be(:namespace_b) { create(:group) }

    before do
      stub_feature_flags(duo_access_through_namespaces: true)
    end

    it 'creates instance accessible entity rules' do
      described_class.duo_namespace_access_rules = [
        { namespace_id: namespace_a.id, access_rules: %w[duo_classic duo_agents] },
        { namespace_id: namespace_b.id, access_rules: %w[duo_flows] }
      ]

      expect(namespace_a.accessible_ai_features_on_instance.pluck(:accessible_entity))
        .to match_array(%w[duo_classic duo_agents])
      expect(namespace_b.accessible_ai_features_on_instance.pluck(:accessible_entity)).to match_array(%w[duo_flows])
    end

    context 'with empty array' do
      before do
        create(:ai_instance_accessible_entity_rules, through_namespace_id: namespace_a.id)
      end

      it 'deletes existing rules and does not create new ones' do
        described_class.duo_namespace_access_rules = []

        expect(Ai::FeatureAccessRule.count).to eq(0)
      end
    end

    context 'when duo_access_through_namespaces feature flag is disabled' do
      before do
        stub_feature_flags(duo_access_through_namespaces: false)
      end

      it 'does not create entity rules' do
        described_class.duo_namespace_access_rules = [
          { namespace_id: namespace_a.id, access_rules: %w[duo_classic duo_agents] }
        ]

        expect(Ai::FeatureAccessRule.count).to eq(0)
      end
    end
  end
end
