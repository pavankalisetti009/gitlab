# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Agents::UpdateService, feature_category: :workflow_catalog do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:agent) { create(:ai_catalog_item, :with_version, public: false, project: project) }
  let_it_be_with_reload(:latest_version) { create(:ai_catalog_item_version, version: '1.1.0', item: agent) }

  let(:tools) { Ai::Catalog::BuiltInTool.where(id: [1, 9]) }
  let(:params) do
    {
      agent: agent,
      name: 'New name',
      description: 'New description',
      public: true,
      tools: tools,
      user_prompt: 'New user prompt',
      system_prompt: 'New system prompt'
    }
  end

  let(:service) { described_class.new(project: project, current_user: user, params: params) }

  describe '#execute' do
    subject(:execute_service) { service.execute }

    shared_examples 'an error response' do |error|
      it 'returns an error response' do
        result = execute_service

        expect(result).to be_error
        expect(result.message).to match_array(Array(error))
        expect(result.payload[:item]).to eq(agent)
      end

      it 'does not update the agent' do
        expect { execute_service }.not_to change { agent.reload.attributes }
      end

      it 'does not update the latest version' do
        expect { execute_service }.not_to change { latest_version.reload.attributes }
      end

      it 'does not trigger track_ai_item_events', :clean_gitlab_redis_shared_state do
        expect { execute_service }
          .not_to trigger_internal_events('update_ai_catalog_item')
      end
    end

    context 'when user lacks permissions' do
      before_all do
        project.add_developer(user)
      end

      it_behaves_like 'an error response', 'You have insufficient permissions'
    end

    context 'when user has permissions' do
      before_all do
        project.add_maintainer(user)
      end

      it 'updates the agent and its latest version' do
        execute_service

        expect(agent.reload).to have_attributes(
          name: 'New name',
          description: 'New description',
          public: true
        )

        expect(latest_version.reload).to have_attributes(
          schema_version: 1,
          version: '1.1.0',
          definition: {
            user_prompt: 'New user prompt',
            tools: [1, 9],
            system_prompt: 'New system prompt'
          }.stringify_keys
        )
      end

      it 'returns success response with item in payload' do
        result = execute_service

        expect(result).to be_success
        expect(result.payload[:item]).to eq(agent)
      end

      it 'trigger track_ai_item_events', :clean_gitlab_redis_shared_state do
        expect { execute_service }
         .to trigger_internal_events('update_ai_catalog_item')
         .with(user: user, project: project, additional_properties: { label: 'agent' })
      end

      context 'when only agent properties are being updated' do
        let(:params) { { agent: agent, name: 'New name' } }

        it 'updates the agent' do
          expect { execute_service }.to change { agent.reload.name }.to('New name')
        end
      end

      describe 'updating the latest version schema version' do
        before do
          stub_const('Ai::Catalog::ItemVersion::AGENT_SCHEMA_VERSION', 987)
          allow(agent).to receive(:latest_version).and_return(latest_version)
          allow(latest_version).to receive(:json_schema_filename).and_return('agent_v1')
        end

        it 'sets it to the current schema version' do
          expect { execute_service }.to change { latest_version.reload.schema_version }.to(987)
        end

        context 'when no version properties are being updated' do
          let(:params) { { agent: agent, name: 'New name' } }

          it 'does not change the current schema version' do
            expect { execute_service }.not_to change { latest_version.reload.schema_version }
          end
        end
      end

      context 'when updated agent is invalid' do
        let(:params) do
          {
            agent: agent,
            name: ''
          }
        end

        it_behaves_like 'an error response', "Item name can't be blank"
      end

      context 'when updated latest version is invalid' do
        before do
          stub_const('Ai::Catalog::ItemVersion::AGENT_SCHEMA_VERSION', nil)
        end

        it_behaves_like 'an error response', "Schema version can't be blank"
      end

      context 'when agent is not an agent' do
        before do
          allow(agent).to receive(:agent?).and_return(false)
        end

        it_behaves_like 'an error response', 'Agent not found'
      end
    end
  end
end
