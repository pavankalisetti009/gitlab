# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::DuoWorkflowPayloadBuilder::Base, feature_category: :duo_workflow do
  let_it_be(:project) { create(:project) }
  let_it_be(:flow_item) { create(:ai_catalog_flow, project: project) }
  let_it_be(:agent_item_1) { create(:ai_catalog_agent, project: project) }
  let_it_be(:agent_item_2) { create(:ai_catalog_agent, project: project) }

  let(:flow_id) { flow_item.id }
  let(:pinned_version_prefix) { '1.1' }

  subject(:builder) { described_class.new(flow_id, pinned_version_prefix) }

  describe 'includes' do
    it 'includes Gitlab::Utils::StrongMemoize' do
      expect(described_class.included_modules).to include(Gitlab::Utils::StrongMemoize)
    end

    it 'includes ActiveModel::Model' do
      expect(described_class.included_modules).to include(ActiveModel::Model)
    end
  end

  describe '#initialize' do
    it 'sets flow_id and pinned_version_prefix' do
      expect(builder.instance_variable_get(:@flow_id)).to eq(flow_id)
      expect(builder.instance_variable_get(:@pinned_version_prefix)).to eq(pinned_version_prefix)
    end
  end

  describe '#build' do
    it 'calls build_flow_config' do
      expect(builder).to receive(:build_flow_config)
      builder.build
    end
  end
end
