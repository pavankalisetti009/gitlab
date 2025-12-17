# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::ItemConsumerPolicy, feature_category: :workflow_catalog do
  let(:user) { nil }

  subject(:policy) { described_class.new(user, item_consumer) }

  context 'when item consumer belongs to a project' do
    let(:item_consumer) { build_stubbed(:ai_catalog_item_consumer, project: build_stubbed(:project)) }

    it { is_expected.to delegate_to(::ProjectPolicy) }
  end

  context 'when item consumer belongs to a group' do
    let(:item_consumer) { build_stubbed(:ai_catalog_item_consumer, group: build_stubbed(:group)) }

    it { is_expected.to delegate_to(::GroupPolicy) }
  end

  describe 'execute_ai_catalog_item' do
    let_it_be(:user) { create(:user) }
    let_it_be(:project) { create(:project, developers: user) }

    let(:flows_available) { false }

    let(:item_consumer) do
      build_stubbed(:ai_catalog_item_consumer,
        project: project,
        item: item
      )
    end

    before do
      allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :ai_catalog).and_return(true)
      allow(::Gitlab::Llm::StageCheck).to receive(:available?)
        .with(project, :ai_catalog_flows).and_return(flows_available)
    end

    context 'when item is flow' do
      let(:item) { build_stubbed(:ai_catalog_flow) }

      context 'when StageCheck :ai_catalog_flows is false' do
        it { is_expected.to be_disallowed(:execute_ai_catalog_item) }
      end

      context 'when StageCheck :ai_catalog_flows is true' do
        let(:flows_available) { true }

        it { is_expected.to be_allowed(:execute_ai_catalog_item) }
      end
    end

    context 'when item is third party flow' do
      let(:item) { build_stubbed(:ai_catalog_third_party_flow) }

      it { is_expected.to be_allowed(:execute_ai_catalog_item) }
    end
  end
end
