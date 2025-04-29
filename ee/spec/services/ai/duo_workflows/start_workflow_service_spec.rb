# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::DuoWorkflows::StartWorkflowService, feature_category: :duo_workflow do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:developer) { create(:user, developer_of: project) }
  let_it_be(:maintainer) { create(:user, maintainer_of: project) }
  let_it_be(:reporter) { create(:user, reporter_of: project) }
  let_it_be(:workflow) { create(:duo_workflows_workflow, project: project, user: maintainer) }
  let_it_be(:params) do
    {
      goal: 'test-goal',
      workflow: workflow,
      workflow_oauth_token: 'test-oauth-token',
      workflow_service_token: 'test-service-token'
    }
  end

  shared_examples "success" do
    it 'starts a pipeline to execute workflow' do
      aggregate_failures do
        expect(execute).to be_success

        pipeline_id = execute.payload[:pipeline_id]

        expect(execute.payload).to eq(
          pipeline_id: pipeline_id,
          pipeline_path: Gitlab::Application.routes.url_helpers.project_pipeline_path(project, pipeline_id)
        )

        ci_pipeline = Ci::Pipeline.find_by_id([pipeline_id])
        expect(ci_pipeline.ref).to start_with('workloads/')
      end
    end
  end

  shared_examples 'failure' do
    it 'does not start a pipeline to execute workflow' do
      expect(execute).to be_error
      expect(execute.reason).to eq(:feature_unavailable)
      expect(execute.message).to eq('Can not execute workflow in CI')
    end
  end

  subject(:execute) { described_class.new(workflow: workflow, params: params).execute }

  context 'with workflow enablement checks' do
    using RSpec::Parameterized::TableSyntax
    where(:duo_workflow_ff, :duo_workflow_in_ci_ff, :duo_features_enabled, :current_user, :shared_examples) do
      false | false | true   | ref(:maintainer) | 'failure'
      true  | false | true   | ref(:developer)  | 'failure'
      false | true  | true   | ref(:developer)  | 'failure'
      true  | true  | true   | ref(:maintainer) | 'success'
      true  | true  | true   | ref(:reporter)   | 'failure'
      true  | true  | false  | ref(:developer)  | 'failure'
    end

    with_them do
      before do
        stub_feature_flags(duo_workflow: duo_workflow_ff, duo_workflow_in_ci: duo_workflow_in_ci_ff)
        allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
        project.project_setting.update!(duo_features_enabled: duo_features_enabled)
        workflow.update!(user: current_user)
      end

      include_examples params[:shared_examples]
    end
  end

  context 'when ci pipeline could not be created' do
    let(:pipeline) do
      instance_double(Ci::Pipeline, created_successfully?: false, full_error_messages: 'full error messages')
    end

    let(:service_response) { ServiceResponse.error(message: 'Error in creating pipeline', payload: pipeline) }

    before do
      allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
      allow_next_instance_of(Ci::CreatePipelineService) do |instance|
        allow(instance).to receive(:execute).and_return(service_response)
      end
      project.project_setting.update!(duo_features_enabled: true)
    end

    it 'does not start a pipeline to execute workflow' do
      expect(execute).to be_error
      expect(execute.reason).to eq(:workload_failure)
      expect(execute.message).to eq('Error in creating pipeline')
    end
  end
end
