# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Pipeline::ExecutionPolicies::PipelineContext, feature_category: :security_policy_management do
  subject(:context) { described_class.new(project: project, command: command) }

  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:user) { create(:user, developer_of: project) }
  let(:pipeline) { build(:ci_pipeline, source: 'push', project: project, ref: 'master', user: user) }
  let(:command) do
    Gitlab::Ci::Pipeline::Chain::Command.new(
      project: project, source: pipeline.source, current_user: user, origin_ref: pipeline.ref
    )
  end

  describe 'delegations' do
    it { is_expected.to delegate_method(:policy_pipelines).to(:pipeline_execution_context) }
    it { is_expected.to delegate_method(:override_policy_stages).to(:pipeline_execution_context) }
    it { is_expected.to delegate_method(:build_policy_pipelines!).to(:pipeline_execution_context) }
    it { is_expected.to delegate_method(:creating_policy_pipeline?).to(:pipeline_execution_context) }
    it { is_expected.to delegate_method(:has_execution_policy_pipelines?).to(:pipeline_execution_context) }
    it { is_expected.to delegate_method(:has_overriding_execution_policy_pipelines?).to(:pipeline_execution_context) }
    it { is_expected.to delegate_method(:collect_declared_stages!).to(:pipeline_execution_context) }
    it { is_expected.to delegate_method(:inject_policy_reserved_stages?).to(:pipeline_execution_context) }
    it { is_expected.to delegate_method(:valid_stage?).to(:pipeline_execution_context) }
  end

  describe '#pipeline_execution_context' do
    it 'initializes it with correct attributes' do
      expect(::Gitlab::Ci::Pipeline::PipelineExecutionPolicies::PipelineContext)
        .to receive(:new).with(context: context, project: project, command: command)

      context.pipeline_execution_context
    end
  end

  describe '#skip_ci_allowed?' do
    subject { context.skip_ci_allowed? }

    it { is_expected.to be(true) }

    context 'when there are pipeline execution policies' do
      before do
        allow(context.pipeline_execution_context).to receive(:has_execution_policy_pipelines?).and_return(true)
      end

      it { is_expected.to be(false) }
    end
  end
end
