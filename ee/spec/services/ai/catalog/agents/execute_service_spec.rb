# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Agents::ExecuteService, :aggregate_failures, feature_category: :workflow_catalog do
  let_it_be(:maintainer) { create(:user) }
  let_it_be(:organization) { create(:organization) }
  let_it_be(:project) { create(:project, :repository, organization: organization, maintainers: maintainer) }
  let_it_be(:agent) { create(:ai_catalog_agent, organization: organization, project: project) }
  let_it_be(:agent_version) { agent.versions.last }

  let_it_be(:service_params) do
    {
      agent: agent,
      agent_version: agent_version,
      execute_workflow: true
    }
  end

  let(:json_config) do
    {
      'version' => 'experimental',
      'environment' => 'remote',
      'components' => be_an(Array),
      'routers' => be_an(Array),
      'flow' => be_a(Hash)
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

    context 'when execute_workflow is false' do
      let(:service_params) { super().merge({ execute_workflow: false }) }

      it_behaves_like 'prevents CI pipeline creation for Duo Workflow' do
        subject { execute }
      end

      it 'does not call execute_workflow_service' do
        expect(::Ai::Catalog::ExecuteWorkflowService).not_to receive(:new)

        result = execute
        parsed_yaml = YAML.safe_load(result[:flow_config])

        expect(result).to be_success
        expect(parsed_yaml).to include(json_config)
      end
    end

    context 'when agent is properly wrapped as a flow and executed' do
      let(:oauth_token) do
        { oauth_access_token: instance_double(Doorkeeper::AccessToken, plaintext_token: 'token-12345') }
      end

      let(:workflow_service_token) do
        { token: 'workflow_token', expires_at: 1.hour.from_now }
      end

      before do
        stub_feature_flags(ci_validate_config_options: false)
        allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
        allow(current_user).to receive(:allowed_to_use?).and_return(true)
        project.project_setting.update!(duo_features_enabled: true, duo_remote_flows_enabled: true)

        allow_next_instance_of(::Ai::DuoWorkflows::TokenGenerationService) do |service|
          allow(service).to receive_messages(
            generate_oauth_token_with_composite_identity_support:
              ServiceResponse.success(payload: oauth_token),
            generate_workflow_token:
              ServiceResponse.success(payload: workflow_service_token),
            use_service_account?: false
          )
        end
      end

      it 'provides a success response containing workflow and flow details' do
        expect(::Ai::Catalog::ExecuteWorkflowService).to receive(:new).and_call_original

        result = execute
        parsed_yaml = YAML.safe_load(result[:flow_config])

        expect(result).to be_success
        expect(parsed_yaml).to include(json_config)
        expect(result[:workflow]).to eq(Ai::DuoWorkflows::Workflow.last)
        expect(result[:workload_id]).to eq(Ci::Workloads::Workload.last.id)
      end

      it_behaves_like 'creates CI pipeline for Duo Workflow execution' do
        subject { execute }
      end

      context 'when workflow execution process fails' do
        let(:execute_workflow_service) { instance_double(::Ai::Catalog::ExecuteWorkflowService) }

        before do
          allow(::Ai::Catalog::ExecuteWorkflowService).to receive(:new).and_return(execute_workflow_service)
          allow(execute_workflow_service).to receive(:execute)
            .and_return(ServiceResponse.error(message: Array('Workflow execution failed')))
        end

        it_behaves_like 'returns error response', 'Workflow execution failed'
      end
    end
  end
end
