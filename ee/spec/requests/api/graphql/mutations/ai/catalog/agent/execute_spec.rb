# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ai::Catalog::Agent::Execute, :aggregate_failures, feature_category: :workflow_catalog do
  include GraphqlHelpers

  let_it_be(:maintainer) { create(:user) }
  let_it_be(:project) { create(:project, maintainers: maintainer) }
  let_it_be_with_reload(:agent) { create(:ai_catalog_agent, project: project) }
  let_it_be_with_reload(:agent_version) { agent.versions.last }

  let(:current_user) { maintainer }
  let(:mutation) do
    graphql_mutation(:ai_catalog_agent_execute, params) do
      <<~FIELDS
        errors
        flowConfig
      FIELDS
    end
  end

  let(:params) do
    {
      agent_id: agent.to_global_id,
      agent_version_id: agent_version.to_global_id
    }
  end

  subject(:execute) { post_graphql_mutation(mutation, current_user: current_user) }

  shared_examples 'an authorization failure' do
    it_behaves_like 'a mutation that returns a top-level access error'

    it 'prevents ExecuteService from being called' do
      expect(::Ai::Catalog::Agents::ExecuteService).not_to receive(:new)

      execute
    end
  end

  shared_examples 'successful execution' do
    it 'returns valid flow config with expected structure' do
      execute

      expect(graphql_data_at(:ai_catalog_agent_execute, :errors)).to be_empty

      flow_config = graphql_data_at(:ai_catalog_agent_execute, :flow_config)
      parsed_yaml = YAML.safe_load(flow_config)
      expect(parsed_yaml).to include(
        'version' => 'experimental',
        'environment' => 'remote',
        'components' => be_an(Array),
        'routers' => be_an(Array),
        'flow' => be_a(Hash)
      )
    end
  end

  context 'when user is a developer' do
    let(:current_user) { create(:user).tap { |user| project.add_developer(user) } }

    it_behaves_like 'an authorization failure'
  end

  context 'when global_ai_catalog feature flag is disabled' do
    before do
      stub_feature_flags(global_ai_catalog: false)
    end

    it_behaves_like 'an authorization failure'
  end

  context 'when the agent does not exist' do
    let(:params) do
      {
        agent_id: Gitlab::GlobalId.build(model_name: 'Ai::Catalog::Item', id: non_existing_record_id)
      }
    end

    it_behaves_like 'an authorization failure'
  end

  context 'when the agent version does not exist' do
    let(:params) do
      {
        agent_id: agent.to_global_id,
        agent_version_id: Gitlab::GlobalId.build(model_name: 'Ai::Catalog::ItemVersion', id: non_existing_record_id)
      }
    end

    it_behaves_like 'an authorization failure'
  end

  context 'when agent_version_id is not provided' do
    let(:params) { super().except(:agent_version_id) }

    it_behaves_like 'successful execution'

    it 'executes the latest version of the agent' do
      latest_agent_version = create(:ai_catalog_item_version, version: '2.0.0', item: agent)
      allow(::Ai::Catalog::Agents::ExecuteService).to receive(:new).and_call_original

      execute

      expect(::Ai::Catalog::Agents::ExecuteService)
        .to have_received(:new).with(agent, latest_agent_version, current_user)
    end
  end

  context 'when both agent_id and agent_version_id are valid' do
    it_behaves_like 'successful execution'
  end

  context 'when execute service fails' do
    let(:error_message) { 'Service execution failed' }
    let(:mock_service) { instance_double(::Ai::Catalog::Agents::ExecuteService) }
    let(:service_result) { ServiceResponse.error(message: error_message) }

    before do
      allow(::Ai::Catalog::Agents::ExecuteService).to receive(:new)
        .with(agent, agent_version, current_user)
        .and_return(mock_service)
      allow(mock_service).to receive(:execute).and_return(service_result)
    end

    it 'returns the service error message' do
      execute

      expect(graphql_data_at(:ai_catalog_agent_execute, :errors)).to contain_exactly(error_message)
      expect(graphql_data_at(:ai_catalog_agent_execute, :flow_config)).to be_nil
    end
  end

  context 'with mismatched agent type and agent version' do
    let_it_be(:flow) { create(:ai_catalog_flow, project: project) }
    let_it_be(:flow_version) { flow.versions.last }

    context 'when a flow item is passed with an agent item version' do
      let(:params) do
        {
          agent_id: flow.to_global_id,
          agent_version_id: agent_version.to_global_id
        }
      end

      it 'returns an error for mismatched item types' do
        execute

        expect(graphql_data_at(:ai_catalog_agent_execute,
          :errors)).to contain_exactly('Agent is required')
        expect(graphql_data_at(:ai_catalog_agent_execute, :flow_config)).to be_nil
      end
    end

    context 'when an agent item is passed with a flow item version' do
      let(:params) do
        {
          agent_id: agent.to_global_id,
          agent_version_id: flow_version.to_global_id
        }
      end

      it 'returns an error for mismatched item types' do
        execute

        expect(graphql_data_at(:ai_catalog_agent_execute,
          :errors)).to contain_exactly('Agent version must belong to the agent')
        expect(graphql_data_at(:ai_catalog_agent_execute, :flow_config)).to be_nil
      end
    end

    context "when an agent is passed with a different agent's version" do
      let_it_be(:other_agent) { create(:ai_catalog_agent, project: project) }
      let_it_be(:other_agent_version) { other_agent.versions.last }

      let(:params) do
        {
          agent_id: agent.to_global_id,
          agent_version_id: other_agent_version.to_global_id
        }
      end

      it 'returns an error for mismatched agent and version' do
        execute

        expect(graphql_data_at(:ai_catalog_agent_execute,
          :errors)).to contain_exactly('Agent version must belong to the agent')
        expect(graphql_data_at(:ai_catalog_agent_execute, :flow_config)).to be_nil
      end
    end
  end
end
