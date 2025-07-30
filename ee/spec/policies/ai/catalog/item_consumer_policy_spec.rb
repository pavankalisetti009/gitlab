# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::ItemConsumerPolicy, feature_category: :duo_chat do
  subject(:policy) { described_class.new(nil, item_consumer) }

  context 'when item consumer belongs to a project' do
    let(:item_consumer) { build_stubbed(:ai_catalog_item_consumer, project: build_stubbed(:project)) }

    it 'delegates to ProjectPolicy' do
      delegations = policy.delegated_policies

      expect(delegations.values).to include(an_instance_of(::ProjectPolicy))
    end
  end

  context 'when item consumer belongs to a group' do
    let(:item_consumer) { build_stubbed(:ai_catalog_item_consumer, group: build_stubbed(:group)) }

    it 'delegates to GroupPolicy' do
      delegations = policy.delegated_policies

      expect(delegations.values).to include(an_instance_of(::GroupPolicy))
    end
  end
end
