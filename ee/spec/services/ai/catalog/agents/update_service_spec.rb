# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Agents::UpdateService, feature_category: :workflow_catalog do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:item) { create(:ai_catalog_item, public: false, project: project) }
  let_it_be_with_reload(:latest_released_version) do
    create(:ai_catalog_item_version, :released, version: '1.0.0', item: item)
  end

  let_it_be_with_reload(:latest_version) { create(:ai_catalog_item_version, version: '1.1.0', item: item) }
  let(:tool_ids) { [1, 9] }
  let(:params) do
    {
      item: item,
      name: 'New name',
      description: 'New description',
      public: true,
      release: true,
      tools: Ai::Catalog::BuiltInTool.where(id: tool_ids),
      user_prompt: 'New user prompt',
      system_prompt: 'New system prompt'
    }
  end

  let(:service) { described_class.new(project: project, current_user: user, params: params) }

  it_behaves_like Ai::Catalog::Items::BaseUpdateService do
    let(:item_schema_version) { Ai::Catalog::ItemVersion::AGENT_SCHEMA_VERSION }
    let(:expected_updated_definition) do
      {
        tools: tool_ids,
        user_prompt: 'New user prompt',
        system_prompt: 'New system prompt'
      }
    end

    context 'when user has permissions' do
      before_all do
        project.add_maintainer(user)
      end

      context 'when agent is not an agent' do
        before do
          allow(item).to receive(:agent?).and_return(false)
        end

        it_behaves_like 'an error response', 'Agent not found'
      end
    end
  end
end
