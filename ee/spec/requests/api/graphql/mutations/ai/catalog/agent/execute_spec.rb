# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ai::Catalog::Agent::Execute, :aggregate_failures, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:project) { create(:project, :repository, developers: current_user) }
  let_it_be_with_reload(:agent) { create(:ai_catalog_agent, project: project) }
  let_it_be_with_reload(:agent_version) do
    agent.versions.last.tap { |version| version.update!(release_date: 1.hour.ago) }
  end

  let(:mutation) do
    graphql_mutation(:ai_catalog_agent_execute, params) do
      <<~FIELDS
        errors
        flowConfig
        workflow {
          id
        }
      FIELDS
    end
  end

  let(:json_config) do
    {
      'version' => 'experimental',
      'environment' => 'remote',
      'components' => be_an(Array),
      'routers' => be_an(Array),
      'flow' => be_a(Hash),
      'prompts' => be_an(Array)
    }
  end

  let(:params) do
    {
      agent_id: agent.to_global_id,
      agent_version_id: agent_version.to_global_id,
      user_prompt: user_prompt
    }
  end

  let(:user_prompt) { 'user prompt' }

  let(:oauth_token) do
    { oauth_access_token: instance_double(Doorkeeper::AccessToken, plaintext_token: 'token-12345') }
  end

  let(:workflow_service_token) do
    { token: 'workflow_token', expires_at: 1.hour.from_now }
  end

  before do
    enable_ai_catalog
    allow(Ability).to receive(:allowed?).and_call_original
    allow(Ability).to receive(:allowed?).with(current_user, :duo_workflow, project).and_return(true)
    allow(Ability).to receive(:allowed?).with(current_user, :execute_duo_workflow_in_ci, anything).and_return(true)
    allow(Ability).to receive(:allowed?).with(current_user, :read_duo_workflow, anything).and_return(true)

    project.project_setting.update!(duo_features_enabled: true, duo_remote_flows_enabled: true)

    allow_next_instance_of(::Ai::DuoWorkflows::WorkflowContextGenerationService) do |service|
      allow(service).to receive_messages(
        generate_oauth_token_with_composite_identity_support:
          ServiceResponse.success(payload: oauth_token),
        generate_workflow_token:
          ServiceResponse.success(payload: workflow_service_token),
        use_service_account?: false
      )
    end
  end

  subject(:execute) { post_graphql_mutation(mutation, current_user: current_user) }

  shared_examples 'an authorization failure' do
    it_behaves_like 'a mutation that returns a top-level access error'

    it 'prevents ExecuteService from being called' do
      expect(::Ai::Catalog::Agents::ExecuteService).not_to receive(:new)

      execute
    end

    it_behaves_like 'prevents CI pipeline creation for Duo Workflow' do
      subject { execute }
    end
  end

  shared_examples 'successful execution' do
    it 'returns valid flow config with expected structure' do
      execute

      flow_config = graphql_data_at(:ai_catalog_agent_execute, :flowConfig)
      parsed_yaml = YAML.safe_load(flow_config)

      workflow = graphql_data_at(:ai_catalog_agent_execute, :workflow)

      expect(graphql_data_at(:ai_catalog_agent_execute, :errors)).to be_empty
      expect(parsed_yaml).to include(json_config)
      expect(workflow).to be_present
    end

    it_behaves_like 'creates CI pipeline for Duo Workflow execution' do
      subject { execute }
    end
  end

  context 'when user is a reporter' do
    let(:current_user) { create(:user).tap { |user| project.add_reporter(user) } }

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
      super().merge(agent_id: Gitlab::GlobalId.build(model_name: 'Ai::Catalog::Item', id: non_existing_record_id))
    end

    it_behaves_like 'an authorization failure'
  end

  context 'when the agent version does not exist' do
    let(:params) do
      super().merge(
        agent_version_id: Gitlab::GlobalId.build(model_name: 'Ai::Catalog::ItemVersion', id: non_existing_record_id)
      )
    end

    it_behaves_like 'an authorization failure'
  end

  context 'when agent_version_id is not provided' do
    let(:params) { super().except(:agent_version_id) }

    it_behaves_like 'successful execution'

    it 'executes the latest version of the agent' do
      latest_agent_version = create(:ai_catalog_item_version, :released, version: '2.0.0', item: agent)
      allow(::Ai::Catalog::Agents::ExecuteService).to receive(:new).and_call_original

      execute

      expect(::Ai::Catalog::Agents::ExecuteService)
        .to have_received(:new).with(
          project: agent.project,
          current_user: current_user,
          params: { agent: agent, agent_version: latest_agent_version, execute_workflow: true,
                    user_prompt: user_prompt }
        )
    end
  end

  context 'when all params are valid' do
    it_behaves_like 'successful execution'

    it 'passes the user prompt as goal to ExecuteWorkflowService' do
      allow(::Ai::Catalog::ExecuteWorkflowService).to receive(:new).and_call_original

      execute

      expect(::Ai::Catalog::ExecuteWorkflowService)
        .to have_received(:new).with(
          current_user,
          hash_including(goal: user_prompt)
        )
    end

    it 'configures prompt template with user_prompt' do
      execute

      flow_config = graphql_data_at(:ai_catalog_agent_execute, :flowConfig)
      parsed_yaml = YAML.safe_load(flow_config)

      expect(parsed_yaml['prompts']).to match([
        {
          'prompt_id' => be_a(String),
          'model' => {
            'params' => {
              'max_tokens' => be_a(Integer),
              'model_class_provider' => be_a(String),
              'model' => be_a(String)
            }
          },
          'prompt_template' => {
            'system' => agent_version.def_system_prompt,
            'user' => user_prompt,
            'placeholder' => be_a(String)
          },
          "params" => { "timeout" => be_a(Integer) }
        }
      ])
    end
  end

  context 'when latest version is still in draft' do
    let_it_be(:agent) { create(:ai_catalog_agent, project: project) }
    let_it_be(:agent_version) do
      agent.versions.last.tap { |version| version.update!(release_date: nil) }
    end

    context 'when user is a developer' do
      it_behaves_like 'an authorization failure'
    end

    context 'when user is a maintainer' do
      let(:current_user) { create(:user).tap { |user| project.add_maintainer(user) } }

      it_behaves_like 'successful execution'
    end
  end

  context 'when execute service fails' do
    let(:error_message) { 'Service execution failed' }
    let(:mock_service) { instance_double(::Ai::Catalog::Agents::ExecuteService) }
    let(:service_result) { ServiceResponse.error(message: error_message) }

    before do
      allow(::Ai::Catalog::Agents::ExecuteService).to receive(:new)
        .with(
          project: agent.project,
          current_user: current_user,
          params: { agent: agent, agent_version: agent_version, execute_workflow: true, user_prompt: user_prompt }
        )
        .and_return(mock_service)
      allow(mock_service).to receive(:execute).and_return(service_result)
    end

    it 'returns the service error message' do
      execute

      expect(graphql_data_at(:ai_catalog_agent_execute, :errors)).to contain_exactly(error_message)
      expect(graphql_data_at(:ai_catalog_agent_execute, :flow_config)).to be_nil
      expect(graphql_data_at(:ai_catalog_agent_execute, :workflow)).to be_nil
    end
  end

  context 'when workflow is not created' do
    let(:mock_service) { instance_double(::Ai::Catalog::Agents::ExecuteService) }
    let(:service_result) do
      ServiceResponse.success(payload: { flow_config: 'test_config', workflow: nil })
    end

    before do
      allow(::Ai::Catalog::Agents::ExecuteService).to receive(:new)
        .with(
          project: agent.project,
          current_user: current_user,
          params: { agent: agent, agent_version: agent_version, execute_workflow: true, user_prompt: user_prompt }
        )
        .and_return(mock_service)
      allow(mock_service).to receive(:execute).and_return(service_result)
    end

    it 'returns nil workflow when workflow is not created' do
      execute

      expect(graphql_data_at(:ai_catalog_agent_execute, :errors)).to be_empty
      expect(graphql_data_at(:ai_catalog_agent_execute, :flow_config)).to eq('test_config')
      expect(graphql_data_at(:ai_catalog_agent_execute, :workflow)).to be_nil
    end
  end

  context 'with mismatched agent type and agent version' do
    let_it_be(:flow) { create(:ai_catalog_flow, project: project) }
    let_it_be(:flow_version) { flow.versions.last.tap { |version| version.update!(release_date: 1.hour.ago) } }

    context 'when a flow item is passed with an agent item version' do
      let(:params) { super().merge(agent_id: flow.to_global_id) }

      it 'returns an error for mismatched item types' do
        execute

        expect(graphql_data_at(:ai_catalog_agent_execute,
          :errors)).to contain_exactly('Agent is required')
        expect(graphql_data_at(:ai_catalog_agent_execute, :flow_config)).to be_nil
        expect(graphql_data_at(:ai_catalog_agent_execute, :workflow)).to be_nil
      end
    end

    context 'when an agent item is passed with a flow item version' do
      let(:params) { super().merge(agent_version_id: flow_version.to_global_id) }

      it 'returns an error for mismatched item types' do
        execute

        expect(graphql_data_at(:ai_catalog_agent_execute,
          :errors)).to contain_exactly('Agent version must belong to the agent')
        expect(graphql_data_at(:ai_catalog_agent_execute, :flow_config)).to be_nil
        expect(graphql_data_at(:ai_catalog_agent_execute, :workflow)).to be_nil
      end
    end

    context "when an agent is passed with a different agent's version" do
      let_it_be(:other_agent) { create(:ai_catalog_agent, project: project) }
      let_it_be(:other_agent_version) do
        other_agent.versions.last.tap { |version| version.update!(release_date: 1.hour.ago) }
      end

      let(:params) { super().merge(agent_version_id: other_agent_version.to_global_id) }

      it 'returns an error for mismatched agent and version' do
        execute

        expect(graphql_data_at(:ai_catalog_agent_execute,
          :errors)).to contain_exactly('Agent version must belong to the agent')
        expect(graphql_data_at(:ai_catalog_agent_execute, :flow_config)).to be_nil
        expect(graphql_data_at(:ai_catalog_agent_execute, :workflow)).to be_nil
      end
    end
  end

  context 'when passing only required arguments (test that mutation handles absence of optional args)' do
    let(:params) { super().slice(:agent_id, :user_prompt) }

    it_behaves_like 'successful execution'
  end
end
