# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::ItemConsumerPolicy, feature_category: :workflow_catalog do
  subject(:policy) { described_class.new(nil, item_consumer) }

  context 'when item consumer belongs to a project' do
    let(:item_consumer) { build_stubbed(:ai_catalog_item_consumer, project: build_stubbed(:project)) }

    it { is_expected.to delegate_to(::ProjectPolicy) }
  end

  context 'when item consumer belongs to a group' do
    let(:item_consumer) { build_stubbed(:ai_catalog_item_consumer, group: build_stubbed(:group)) }

    it { is_expected.to delegate_to(::GroupPolicy) }
  end
end
