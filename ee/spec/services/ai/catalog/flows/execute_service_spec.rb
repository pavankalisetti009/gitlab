# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Flows::ExecuteService, :aggregate_failures, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers

  let_it_be(:developer) { create(:user) }
  let_it_be(:project) { create(:project, :repository, developers: developer) }
  let_it_be(:flow) { create(:ai_catalog_flow, project: project) }
  let_it_be(:user_prompt) { nil }

  let_it_be_with_reload(:flow_version) do
    item_version = flow.latest_version
    item_version.update!(release_date: 1.hour.ago)
    item_version
  end

  let(:service_params) do
    {
      flow: flow,
      flow_version: flow_version,
      event_type: 'manual',
      execute_workflow: true,
      user_prompt: user_prompt
    }
  end

  let(:expected_flow_config) do
    flow_version.definition.except('yaml_definition')
  end

  let(:current_user) { developer }

  let(:service) do
    described_class.new(
      project: project,
      current_user: current_user,
      params: service_params
    )
  end

  before do
    enable_ai_catalog
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
      let(:current_user) { create(:user).tap { |user| project.add_reporter(user) } }

      it_behaves_like 'returns error response', 'You have insufficient permissions'

      context 'when current_user is nil' do
        let(:current_user) { nil }

        it_behaves_like 'returns error response', 'You have insufficient permissions'
      end
    end

    context 'when flow is nil' do
      let(:service_params) { super().merge({ flow: nil }) }

      it_behaves_like 'returns error response', 'Flow is required'
    end

    context 'when flow item_type is agent' do
      let(:service_params) { super().merge({ flow: build(:ai_catalog_agent) }) }

      it_behaves_like 'returns error response', 'Flow is required'
    end

    context 'when flow_version is nil' do
      let(:service_params) { super().merge({ flow_version: nil }) }

      it_behaves_like 'returns error response', 'Flow version is required'
    end

    context 'when event_type is nil' do
      let(:service_params) { super().merge({ event_type: nil }) }

      it_behaves_like 'returns error response', 'Trigger event type is required'
    end

    context 'when flow_version does not belong to the flow' do
      let(:other_flow) { build(:ai_catalog_flow, project: project) }
      let(:other_flow_version) { other_flow.versions.last.tap { |version| version.release_date = 1.hour.ago } }
      let(:service_params) { super().merge({ flow_version: other_flow_version }) }

      it_behaves_like 'returns error response', 'Flow version must belong to the flow'
    end

    context 'when execute_workflow is false' do
      let(:service_params) { super().merge({ execute_workflow: false }) }

      it_behaves_like 'prevents CI pipeline creation for Duo Workflow' do
        subject { execute }
      end

      it 'does not call execute_workflow_service' do
        expect(::Ai::Catalog::ExecuteWorkflowService).not_to receive(:new)

        result = execute
        parsed_yaml = YAML.safe_load(result.payload[:flow_config], aliases: true)

        expect(result).to be_success
        expect(parsed_yaml).to eq(expected_flow_config)
      end
    end

    context 'when flow is properly executed' do
      let(:oauth_token) do
        { oauth_access_token: instance_double(Doorkeeper::AccessToken, plaintext_token: '***********') }
      end

      let(:workflow_service_token) do
        { token: 'workflow_token', expires_at: 1.hour.from_now }
      end

      before do
        allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
        allow(current_user).to receive(:allowed_to_use?).and_return(true)
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

      it 'provides a success response containing workflow and flow details' do
        expect(::Ai::Catalog::ExecuteWorkflowService).to receive(:new).with(
          current_user,
          hash_including(
            json_config: be_a(Hash),
            container: project,
            goal: flow.description,
            item_version: flow_version
          )
        ).and_call_original

        result = execute
        parsed_yaml = YAML.safe_load(result.payload[:flow_config], aliases: true)

        expect(result).to be_success
        expect(parsed_yaml).to eq(expected_flow_config)
        expect(result.payload[:workflow]).to eq(Ai::DuoWorkflows::Workflow.last)
        expect(result.payload[:workload_id]).to eq(Ci::Workloads::Workload.last.id)
      end

      it 'triggers trigger_ai_catalog_item', :clean_gitlab_redis_shared_state do
        expect { execute }
          .to trigger_internal_events('trigger_ai_catalog_item')
          .with(
            user: current_user,
            project: project,
            additional_properties: {
              label: flow.item_type,
              property: 'manual',
              value: flow.id
            }
          )
          .and increment_usage_metrics(
            'counts.count_total_trigger_ai_catalog_item_weekly',
            'counts.count_total_trigger_ai_catalog_item_monthly',
            'counts.count_total_trigger_ai_catalog_item'
          )
      end

      context 'when catalog item flow is triggered by a different event' do
        let(:service_params) do
          super().merge(event_type: 'mention')
        end

        it 'triggers trigger_ai_catalog_item with the event', :clean_gitlab_redis_shared_state do
          expect { execute }
            .to trigger_internal_events('trigger_ai_catalog_item')
            .with(
              user: current_user,
              project: project,
              additional_properties: {
                label: flow.item_type,
                property: 'mention',
                value: flow.id
              }
            )
            .and increment_usage_metrics(
              'counts.count_total_trigger_ai_catalog_item_weekly',
              'counts.count_total_trigger_ai_catalog_item_monthly',
              'counts.count_total_trigger_ai_catalog_item'
            )
        end
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

      context 'when user_prompt is specified' do
        let(:service_params) { super().merge({ user_prompt: "test input" }) }

        it 'passes user_prompt as goal to ExecuteWorkflowService' do
          expect(::Ai::Catalog::ExecuteWorkflowService).to receive(:new).with(
            current_user,
            hash_including(
              json_config: be_a(Hash),
              container: project,
              goal: "test input",
              item_version: flow_version
            )
          ).and_call_original

          result = execute
          parsed_yaml = YAML.safe_load(result.payload[:flow_config], aliases: true)

          expect(result).to be_success
          expect(parsed_yaml).to eq(expected_flow_config)
        end
      end
    end
  end
end
