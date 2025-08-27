# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Agents::ExecuteService, :aggregate_failures, feature_category: :workflow_catalog do
  let_it_be(:maintainer) { create(:user) }
  let_it_be(:organization) { create(:organization) }
  let_it_be(:project) { create(:project, organization: organization, maintainers: maintainer) }
  let_it_be(:agent) { create(:ai_catalog_agent, organization: organization, project: project) }
  let_it_be(:agent_version) { agent.versions.last }

  let_it_be(:service_params) do
    {
      agent: agent,
      agent_version: agent_version
    }
  end

  let(:current_user) { maintainer }

  let(:service) do
    described_class.new(
      project: project,
      current_user: current_user,
      params: service_params
    )
  end

  describe '#execute' do
    subject(:execute) { service.execute }

    shared_examples 'returns error response' do |expected_message|
      it 'returns an error service response' do
        result = execute

        expect(result).to be_error
        expect(result.message).to match_array(expected_message)
      end
    end

    context 'with valid inputs' do
      it 'returns a successful service response with flow config' do
        result = execute

        expect(result).to be_success

        yaml_content = result[:flow_config]
        parsed_yaml = YAML.safe_load(yaml_content)
        expect(parsed_yaml).to include(
          'version' => 'experimental',
          'environment' => 'remote',
          'components' => be_an(Array),
          'routers' => be_an(Array),
          'flow' => be_a(Hash)
        )
      end
    end

    context 'when user lack permission' do
      let(:current_user) { create(:user).tap { |user| project.add_developer(user) } }

      it_behaves_like 'returns error response', 'You have insufficient permissions'

      context 'when current_user is nil' do
        let(:current_user) { nil }

        it_behaves_like 'returns error response', 'You have insufficient permissions'
      end
    end

    context 'when wrapped_agent_response has error' do
      before do
        allow_next_instance_of(::Ai::Catalog::WrappedAgentFlowBuilder) do |builder|
          allow(builder).to receive(:execute).and_return(ServiceResponse.error(message: ['Generated flow is invalid']))
        end
      end

      it_behaves_like 'returns error response', 'Generated flow is invalid'
    end

    context 'when agent is nil' do
      let(:service_params) { super().merge({ agent: nil }) }

      it_behaves_like 'returns error response', 'Agent is required'
    end

    context 'when agent item_type is flow' do
      let(:service_params) { super().merge({ agent: build(:ai_catalog_flow) }) }

      it_behaves_like 'returns error response', 'Agent is required'
    end

    context 'when agent_version is nil' do
      let(:service_params) { super().merge({ agent_version: nil }) }

      it_behaves_like 'returns error response', 'Agent version is required'
    end

    context 'when agent_version does not belong to the agent' do
      let(:other_agent) { build(:ai_catalog_agent, organization: organization, project: project) }
      let(:other_agent_version) { other_agent.versions.last }
      let(:service_params) { super().merge({ agent_version: other_agent_version }) }

      it_behaves_like 'returns error response', 'Agent version must belong to the agent'
    end
  end
end
