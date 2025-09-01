# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::FlowTriggers::RunService, feature_category: :agent_foundations do
  let_it_be_with_refind(:project) { create(:project, :repository) }

  let_it_be(:current_user) { create(:user, maintainer_of: project) }
  let_it_be(:resource) { create(:issue, project: project) }
  let_it_be(:service_account) { create(:service_account, maintainer_of: project) }
  let_it_be(:existing_note) { create(:note, project: project, noteable: resource) }

  let(:params) { { input: 'test input', event: 'mention', discussion: existing_note.discussion } }

  let_it_be(:flow_trigger) do
    create(:ai_flow_trigger, project: project, user: service_account, config_path: '.gitlab/duo/flow.yml')
  end

  let_it_be(:flow_definition) do
    {
      'image' => 'ruby:3.0',
      'commands' => ['echo "Hello World"', 'ruby script.rb'],
      'variables' => %w[API_KEY DATABASE_URL]
    }
  end

  let_it_be(:project_variable1) do
    create(:ci_variable, project: project, key: 'DATABASE_URL', value: 'postgres://test')
  end

  let_it_be(:project_variable2) { create(:ci_variable, project: project, key: 'API_KEY', value: 'secret123') }
  let_it_be(:project_variable3) do
    create(:ci_variable, project: project, key: 'ANOTHER_VAR_THAT_SHOULD_NOT_BE_PASSED', value: 'really secret')
  end

  let_it_be(:flow_definition_yaml) { flow_definition.to_yaml }

  subject(:service) do
    described_class.new(
      project: project,
      current_user: current_user,
      resource: resource,
      flow_trigger: flow_trigger
    )
  end

  before do
    # Enable necessary feature flags and settings
    stub_feature_flags(ci_validate_config_options: false)
    stub_feature_flags(duo_workflow: true, duo_workflow_in_ci: true)

    # Enable duo features on project
    project.project_setting.update!(
      duo_features_enabled: true,
      duo_remote_flows_enabled: true
    )

    # Setup LLM stage check
    allow(::Gitlab::Llm::StageCheck).to receive(:available?).and_return(true)
    allow(::Ability).to receive(:allowed?).and_return(true)
    allow(current_user).to receive(:allowed_to_use?).and_return(true)

    # Setup chat authorizer
    authorizer_double = instance_double(::Gitlab::Llm::Utils::Authorizer::Response)
    allow(::Gitlab::Llm::Chain::Utils::ChatAuthorizer)
      .to receive(:resource)
      .and_return(authorizer_double)
    allow(authorizer_double).to receive(:allowed?).and_return(true)
  end

  describe '#execute' do
    before_all do
      project.repository.create_file(
        project.creator,
        '.gitlab/duo/flow.yml',
        flow_definition_yaml,
        message: 'Create flow definition',
        branch_name: project.default_branch_or_main)
    end

    it 'creates duo workflow with correct parameters' do
      expect { service.execute(params) }.to change { ::Ai::DuoWorkflows::Workflow.count }.by(1)

      workflow = ::Ai::DuoWorkflows::Workflow.last
      expect(workflow.workflow_definition).to eq("Trigger - #{flow_trigger.description}")
      expect(workflow.goal).to eq('test input') # Changed from discussion to input
      expect(workflow.environment).to eq('web')
      expect(workflow.project).to eq(project)
      expect(workflow.user).to eq(current_user)
    end

    it 'creates workflow_workload association' do
      expect { service.execute(params) }.to change { ::Ai::DuoWorkflows::WorkflowsWorkload.count }.by(1)

      workflow = ::Ai::DuoWorkflows::Workflow.last
      workload = ::Ci::Workloads::Workload.last

      association = ::Ai::DuoWorkflows::WorkflowsWorkload.last
      expect(association.workflow).to eq(workflow)
      expect(association.project_id).to eq(project.id)
      expect(association.workload_id).to eq(workload.id)
    end

    it 'executes the workload service and creates a workload' do
      expect { service.execute(params) }.to change { ::Ci::Workloads::Workload.count }.by(1)

      response = service.execute(params)
      expect(response).to be_success

      workload = response.payload
      expect(workload).to be_persisted
      expect(workload.variable_inclusions.map(&:variable_name)).to eq(%w[API_KEY DATABASE_URL])
    end

    it 'builds workload definition with correct settings' do
      expect(::Ci::Workloads::RunWorkloadService).to receive(:new).and_wrap_original do |original_method, kwargs|
        workload_definition = kwargs[:workload_definition]
        expect(workload_definition.image).to eq('ruby:3.0')
        expect(workload_definition.commands).to eq(['echo "Hello World"', 'ruby script.rb'])
        variables = workload_definition.variables

        expect(variables[:AI_FLOW_CONTEXT]).to match(/id..#{resource.id}/)
        expect(variables[:AI_FLOW_INPUT]).to eq('test input')
        expect(variables[:AI_FLOW_EVENT]).to eq('mention')
        expect(variables[:AI_FLOW_DISCUSSION_ID]).to eq(existing_note.discussion_id)
        expect(variables[:AI_FLOW_ID]).to eq(::Ai::DuoWorkflows::Workflow.last.id)

        expect(kwargs[:ci_variables_included]).to eq(%w[API_KEY DATABASE_URL])
        expect(kwargs[:source]).to eq(:duo_workflow)

        original_method.call(**kwargs)
      end

      response = service.execute(params)
      expect(response).to be_success
    end

    it 'creates appropriate notes' do
      expect(Note.count).to eq(1)
      expect(::Ci::Workloads::Workload.count).to eq(0)

      response = service.execute(params)

      expect(response).to be_success
      expect(::Ci::Workloads::Workload.count).to eq(1)
      expect(Note.count).to eq(2)

      expect(Note.last.note).to include('✅ Agent has started. You can view the progress')

      logs_url = ::Ci::Workloads::Workload.last.logs_url
      expect(Note.last.note).to include(logs_url)
    end

    it 'updates workflow status to running initially and then to start on success' do
      response = service.execute(params)
      expect(response).to be_success

      workflow = ::Ai::DuoWorkflows::Workflow.last
      expect(workflow.status_name).to eq(:running)
    end

    context 'when workload execution fails' do
      before do
        allow_next_instance_of(::Ci::Workloads::RunWorkloadService) do |instance|
          error = ServiceResponse.error(
            message: 'Workload failed', payload: instance_double(::Ci::Workloads::Workload, id: 999)
          )

          allow(instance).to receive(:execute).and_return(error)
        end
      end

      it 'still creates workflow and handles the failure' do
        expect { service.execute(params) }.to change { ::Ai::DuoWorkflows::Workflow.count }.by(1)

        # The service should still attempt to update workflow status even on failure
        workflow = ::Ai::DuoWorkflows::Workflow.last
        expect(workflow).to be_present
      end
    end

    context 'when workflow creation fails' do
      before do
        allow_next_instance_of(::Ai::DuoWorkflows::CreateWorkflowService) do |instance|
          error_response = ServiceResponse.error(message: 'Workflow creation failed')
          allow(error_response).to receive(:error?).and_return(true)
          allow(instance).to receive(:execute).and_return(error_response)
        end
      end

      it 'returns error response without creating workload' do
        expect { service.execute(params) }.not_to change { ::Ci::Workloads::Workload.count }

        response = service.execute(params)
        expect(response).to be_error
        expect(response.message).to eq('Workflow creation failed')
      end
    end

    context 'when resource is a MergeRequest' do
      let_it_be(:merge_request) do
        create(:merge_request,
          source_project: project,
          target_project: project,
          source_branch: 'feature-branch',
          target_branch: 'another-branch'
        )
      end

      let_it_be(:resource) { merge_request }

      it 'includes source branch in branch args' do
        expect(Ci::Workloads::RunWorkloadService).to receive(:new).with(
          project: project,
          current_user: service_account,
          source: :duo_workflow,
          workload_definition: an_instance_of(Ci::Workloads::WorkloadDefinition),
          ci_variables_included: %w[API_KEY DATABASE_URL],
          create_branch: true,
          source_branch: 'feature-branch'
        ).and_call_original

        service.execute(params)
      end
    end

    context 'when resource is not a MergeRequest' do
      it 'does not include source branch in branch args' do
        expect(Ci::Workloads::RunWorkloadService).to receive(:new).with(
          project: project,
          current_user: service_account,
          source: :duo_workflow,
          workload_definition: an_instance_of(Ci::Workloads::WorkloadDefinition),
          ci_variables_included: %w[API_KEY DATABASE_URL],
          create_branch: true
        ).and_call_original

        service.execute(params)
      end
    end

    context 'when flow definition file does not exist' do
      let_it_be_with_refind(:project) { create(:project, :repository) }

      it 'returns error without calling workload service' do
        expect { service.execute(params) }.to change { ::Ai::DuoWorkflows::Workflow.count }.by(1)

        response = service.execute(params)
        expect(response).to be_error
        expect(response.message).to eq('invalid or missing flow definition')
      end
    end

    context 'when flow definition is not a valid' do
      where(:flow_definition_yaml) do
        ['invalid yaml', '[not_a_hash]', "--- &1\n- *1\n", "%x"]
      end

      with_them do
        let_it_be(:project) { create(:project, :repository) }

        before do
          project.repository.create_file(
            project.creator,
            '.gitlab/duo/flow.yml',
            flow_definition_yaml,
            message: 'Create flow definition',
            branch_name: project.default_branch_or_main)
        end

        it 'returns nil without calling workload service' do
          expect(Ci::Workloads::RunWorkloadService).not_to receive(:new)

          expect do
            response = service.execute(params)

            expect(response).to be_error
            expect(response.message).to eq('invalid or missing flow definition')
          end.to change { ::Ai::DuoWorkflows::Workflow.count }.by(1)
        end
      end
    end
  end
end
