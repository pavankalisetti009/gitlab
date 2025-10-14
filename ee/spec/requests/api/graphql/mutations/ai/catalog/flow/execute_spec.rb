# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ai::Catalog::Flow::Execute, :aggregate_failures, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:project) { create(:project, :repository, developers: current_user) }
  let_it_be(:flow_item) { create(:ai_catalog_flow, project: project) }
  let_it_be(:agent_item_1) { create(:ai_catalog_item, :agent, project: project) }
  let_it_be(:agent_item_2) { create(:ai_catalog_item, :agent, project: project) }
  let_it_be(:tool_ids) { [1, 2, 5] } # 1 => "gitlab_blob_search" 2 => 'ci_linter', 5 =>  'create_epic'

  let_it_be(:agent_definition) do
    {
      'system_prompt' => 'Talk like a pirate!',
      'user_prompt' => 'What is a leap year?',
      'tools' => tool_ids
    }
  end

  let_it_be(:agent1_v1) do
    create(:ai_catalog_agent_version, item: agent_item_1, definition: agent_definition, version: '1.1.0')
  end

  let_it_be(:agent2_v1) do
    create(:ai_catalog_agent_version, item: agent_item_2, definition: agent_definition, version: '1.1.1')
  end

  let_it_be(:flow_definition) do
    {
      'triggers' => [1],
      'steps' => [
        { 'agent_id' => agent_item_1.id, 'current_version_id' => agent1_v1.id, 'pinned_version_prefix' => nil },
        { 'agent_id' => agent_item_2.id, 'current_version_id' => agent2_v1.id, 'pinned_version_prefix' => nil }
      ]
    }
  end

  let_it_be_with_reload(:flow_version) do
    item_version = flow_item.latest_version
    item_version.update!(definition: flow_definition, release_date: 1.hour.ago)
    item_version
  end

  let(:mutation) do
    graphql_mutation(:ai_catalog_flow_execute, params) do
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
      flow_id: flow_item.to_global_id,
      flow_version_id: flow_version.to_global_id
    }
  end

  let(:oauth_token) do
    { oauth_access_token: instance_double(Doorkeeper::AccessToken, plaintext_token: '***********') }
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
      expect(::Ai::Catalog::Flows::ExecuteService).not_to receive(:new)

      execute
    end

    it_behaves_like 'prevents CI pipeline creation for Duo Workflow' do
      subject { execute }
    end
  end

  shared_examples 'successful execution' do
    it 'returns valid flow config with expected structure' do
      execute

      flow_config = graphql_data_at(:ai_catalog_flow_execute, :flowConfig)
      parsed_yaml = YAML.safe_load(flow_config, aliases: true)
      workflow = graphql_data_at(:ai_catalog_flow_execute, :workflow)

      expect(graphql_data_at(:ai_catalog_flow_execute, :errors)).to be_empty
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

  context 'when the flow does not exist' do
    let(:params) do
      {
        flow_id: Gitlab::GlobalId.build(model_name: 'Ai::Catalog::Item', id: non_existing_record_id)
      }
    end

    it_behaves_like 'an authorization failure'
  end

  context 'when the flow version does not exist' do
    let(:params) do
      {
        flow_id: flow_item.to_global_id,
        flow_version_id: Gitlab::GlobalId.build(model_name: 'Ai::Catalog::ItemVersion', id: non_existing_record_id)
      }
    end

    it_behaves_like 'an authorization failure'
  end

  context 'when flow_version_id is not provided' do
    let(:params) { super().except(:flow_version_id) }

    it_behaves_like 'successful execution'

    it 'executes the latest version of the flow' do
      latest_flow_version = create(
        :ai_catalog_flow_version, :released, version: '2.0.0', item: flow_item, definition: flow_definition
      )
      allow(::Ai::Catalog::Flows::ExecuteService).to receive(:new).and_call_original

      execute

      expect(::Ai::Catalog::Flows::ExecuteService)
        .to have_received(:new).with(
          project: flow_item.project,
          current_user: current_user,
          params: {
            flow: flow_item,
            flow_version: latest_flow_version,
            event_type: 'manual',
            execute_workflow: true
          }
        )
    end
  end

  context 'when both flow_id and flow_version_id are valid' do
    it_behaves_like 'successful execution'
  end

  context 'when execute service fails' do
    let(:error_message) { 'Service execution failed' }
    let(:mock_service) { instance_double(::Ai::Catalog::Flows::ExecuteService) }
    let(:service_result) { ServiceResponse.error(message: error_message) }

    before do
      allow(::Ai::Catalog::Flows::ExecuteService).to receive(:new)
        .with(
          project: flow_item.project,
          current_user: current_user,
          params: {
            flow: flow_item,
            flow_version: flow_version,
            event_type: 'manual',
            execute_workflow: true
          }
        )
        .and_return(mock_service)
      allow(mock_service).to receive(:execute).and_return(service_result)
    end

    it 'returns the service error message' do
      execute

      expect(graphql_data_at(:ai_catalog_flow_execute, :errors)).to contain_exactly(error_message)
      expect(graphql_data_at(:ai_catalog_flow_execute, :flow_config)).to be_nil
      expect(graphql_data_at(:ai_catalog_flow_execute, :workflow)).to be_nil
    end
  end

  context 'when latest version is still in draft' do
    let_it_be(:flow_item) { create(:ai_catalog_flow, project: project) }
    let_it_be(:flow_version) do
      flow_item.versions.last.tap { |version| version.update!(release_date: nil) }
    end

    context 'when user is a developer' do
      it_behaves_like 'an authorization failure'
    end

    context 'when user is a maintainer' do
      let(:current_user) { create(:user).tap { |user| project.add_maintainer(user) } }

      it_behaves_like 'successful execution'
    end
  end

  context 'when workflow is not created' do
    let(:mock_service) { instance_double(::Ai::Catalog::Flows::ExecuteService) }
    let(:service_result) do
      ServiceResponse.success(payload: { flow_config: 'test_config', workflow: nil })
    end

    before do
      allow(::Ai::Catalog::Flows::ExecuteService).to receive(:new)
        .with(
          project: flow_item.project,
          current_user: current_user,
          params: {
            flow: flow_item,
            flow_version: flow_version,
            event_type: 'manual',
            execute_workflow: true
          }
        )
        .and_return(mock_service)
      allow(mock_service).to receive(:execute).and_return(service_result)
    end

    it 'returns nil workflow when workflow is not created' do
      execute

      expect(graphql_data_at(:ai_catalog_flow_execute, :errors)).to be_empty
      expect(graphql_data_at(:ai_catalog_flow_execute, :flow_config)).to eq('test_config')
      expect(graphql_data_at(:ai_catalog_flow_execute, :workflow)).to be_nil
    end
  end

  context 'with mismatched flow type and flow version' do
    let_it_be(:agent) { create(:ai_catalog_agent, project: project) }
    let_it_be(:agent_version) do
      agent.versions.last.tap { |version| version.update!(release_date: 1.hour.ago) }
    end

    context 'when an agent item is passed with a flow item version' do
      let(:params) do
        {
          flow_id: agent.to_global_id,
          flow_version_id: flow_version.to_global_id
        }
      end

      it 'returns an error for mismatched item types' do
        execute

        expect(graphql_data_at(:ai_catalog_flow_execute,
          :errors)).to contain_exactly('Flow is required')
        expect(graphql_data_at(:ai_catalog_flow_execute, :flow_config)).to be_nil
        expect(graphql_data_at(:ai_catalog_flow_execute, :workflow)).to be_nil
      end
    end

    context 'when a flow item is passed with an agent item version' do
      let(:params) do
        {
          flow_id: flow_item.to_global_id,
          flow_version_id: agent_version.to_global_id
        }
      end

      it 'returns an error for mismatched item types' do
        execute

        expect(graphql_data_at(:ai_catalog_flow_execute,
          :errors)).to contain_exactly('Flow version must belong to the flow')
        expect(graphql_data_at(:ai_catalog_flow_execute, :flow_config)).to be_nil
        expect(graphql_data_at(:ai_catalog_flow_execute, :workflow)).to be_nil
      end
    end

    context "when a flow is passed with a different flow's version" do
      let_it_be(:other_flow) { create(:ai_catalog_flow, project: project) }
      let_it_be(:other_flow_version) do
        other_flow.versions.last.tap { |version| version.update!(release_date: 1.hour.ago) }
      end

      let(:params) do
        {
          flow_id: flow_item.to_global_id,
          flow_version_id: other_flow_version.to_global_id
        }
      end

      it 'returns an error for mismatched flow and version' do
        execute

        expect(graphql_data_at(:ai_catalog_flow_execute,
          :errors)).to contain_exactly('Flow version must belong to the flow')
        expect(graphql_data_at(:ai_catalog_flow_execute, :flow_config)).to be_nil
        expect(graphql_data_at(:ai_catalog_flow_execute, :workflow)).to be_nil
      end
    end
  end
end
