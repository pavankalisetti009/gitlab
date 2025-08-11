# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::FlowTriggers::RunService, feature_category: :duo_workflow do
  let(:project) { create(:project, :repository) }
  let(:current_user) { create(:user, maintainer_of: project) }
  let(:resource) { create(:issue, project: project) }
  let(:params) { { input: 'test input', event: 'mention' } }
  let(:service_account) { create(:service_account, maintainer_of: project) }

  let(:flow_trigger) do
    create(:ai_flow_trigger, project: project, user: service_account, config_path: '.gitlab/duo/flow.yml')
  end

  let(:flow_definition) do
    {
      'image' => 'ruby:3.0',
      'commands' => ['echo "Hello World"', 'ruby script.rb']
    }
  end

  let(:flow_definition_yaml) { flow_definition.to_yaml }

  subject(:service) do
    described_class.new(
      project: project,
      current_user: current_user,
      resource: resource,
      flow_trigger: flow_trigger
    )
  end

  describe '#execute' do
    before do
      project.repository.create_file(
        project.creator,
        '.gitlab/duo/flow.yml',
        flow_definition_yaml,
        message: 'Create flow definition',
        branch_name: project.default_branch_or_main)
      authorizer_double = instance_double(::Gitlab::Llm::Utils::Authorizer::Response)
      allow(::Gitlab::Llm::Chain::Utils::ChatAuthorizer)
        .to receive(:resource)
        .and_return(authorizer_double)
      allow(authorizer_double).to receive(:allowed?).and_return(true)
    end

    it 'executes the workload service and creates a workload' do
      expect { service.execute(params) }.to change { ::Ci::Workloads::Workload.count }.by(1)
    end

    it 'builds workload definition with correct settings' do
      expect(Ci::Workloads::RunWorkloadService).to receive(:new) do
        workload_definition = args[:workload_definition]
        expect(workload_definition.image).to eq('ruby:3.0')
        expect(workload_definition.commands).to eq(['echo "Hello World"', 'ruby script.rb'])
        variables = workload_definition.variables

        expect(variables['AI_FLOW_CONTEXT']).to eq(serialized_resource)
        expect(variables['AI_FLOW_INPUT']).to eq('test input')
        expect(variables['AI_FLOW_EVENT']).to eq('mention')
      end.and_call_original

      service.execute(params)
    end

    it 'returns the result from workload service' do
      expected_result = ServiceResponse.success(payload: { workload_id: 123 })
      expect_next_instance_of(Ci::Workloads::RunWorkloadService) do |instance|
        expect(instance).to receive(:execute).and_return(expected_result)
      end

      result = service.execute(params)

      expect(result).to eq(expected_result)
    end

    context 'when resource is a MergeRequest' do
      let(:merge_request) do
        create(:merge_request,
          source_project: project,
          target_project: project,
          source_branch: 'feature-branch',
          target_branch: 'another-branch'
        )
      end

      let(:resource) { merge_request }

      it 'includes source branch in branch args' do
        expect(Ci::Workloads::RunWorkloadService).to receive(:new).with(
          project: project,
          current_user: service_account,
          source: :duo_workflow,
          workload_definition: an_instance_of(Ci::Workloads::WorkloadDefinition),
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
          create_branch: true
        ).and_call_original

        service.execute(params)
      end
    end

    context 'when flow definition file does not exist' do
      before do
        project.repository.delete_file(
          project.creator,
          '.gitlab/duo/flow.yml',
          message: 'Create flow definition',
          branch_name: project.default_branch_or_main)
      end

      it 'returns nil without calling workload service' do
        expect(Ci::Workloads::RunWorkloadService).not_to receive(:new)

        result = service.execute(params)

        expect(result).to be_nil
      end
    end

    context 'when flow definition is invalid YAML' do
      let(:flow_definition_yaml) { "invalid yaml'" }

      it 'returns nil without calling workload service' do
        expect(Ci::Workloads::RunWorkloadService).not_to receive(:new)

        result = service.execute(params)

        expect(result).to be_nil
      end
    end

    context 'when flow definition is not a hash' do
      let(:flow_definition_yaml) { '[not_a_hash]' }

      it 'returns nil without calling workload service' do
        expect(Ci::Workloads::RunWorkloadService).not_to receive(:new)

        result = service.execute(params)

        expect(result).to be_nil
      end
    end

    context 'when YAML parsing raises an exception' do
      before do
        allow(YAML).to receive(:safe_load).and_raise(Psych::SyntaxError.new('file', 1, 1, 0, 'problem', 'context'))
      end

      it 'returns nil without calling workload service' do
        expect(Ci::Workloads::RunWorkloadService).not_to receive(:new)

        result = service.execute(params)

        expect(result).to be_nil
      end
    end
  end
end
