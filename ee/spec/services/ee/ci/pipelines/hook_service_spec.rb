# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::Pipelines::HookService, feature_category: :continuous_integration do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :repository, group: group) }
  let_it_be(:pipeline, reload: true) { create(:ci_empty_pipeline, :created, project: project) }

  subject(:service) { described_class.new(pipeline) }

  describe '#execute' do
    let(:hook_data) { {} }
    let(:workload) { false }

    before do
      allow(Gitlab::DataBuilder::Pipeline).to receive(:build).with(pipeline).and_return(hook_data)
      allow(pipeline).to receive(:workload?).and_return(workload)
    end

    it 'calls execute_flow_triggers on project' do
      expect(pipeline.project).to receive(:execute_flow_triggers).with(hook_data, described_class::HOOK_NAME)

      service.execute
    end

    context 'when pipeline is a workload' do
      let(:workload) { true }

      it 'does not call execute_flow_triggers on project' do
        expect(project).not_to receive(:execute_flow_triggers)

        service.execute
      end
    end

    context 'when ai_flow_trigger_pipeline_hooks feature flag is disabled' do
      before do
        stub_feature_flags(ai_flow_trigger_pipeline_hooks: false)
      end

      it 'does not call execute_flow_triggers on project' do
        expect(project).not_to receive(:execute_flow_triggers)

        service.execute
      end
    end

    context 'when project has active hooks' do
      let!(:hook) { create(:project_hook, project: project, pipeline_events: true) }

      it 'calls both parent execute and execute_flow_triggers' do
        expect(pipeline.project).to receive(:execute_hooks).with(hook_data, described_class::HOOK_NAME)
        expect(pipeline.project).to receive(:execute_flow_triggers).with(hook_data, described_class::HOOK_NAME)

        service.execute
      end
    end
  end
end
