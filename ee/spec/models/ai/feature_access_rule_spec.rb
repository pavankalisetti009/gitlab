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
end
