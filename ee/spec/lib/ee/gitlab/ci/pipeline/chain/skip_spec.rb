# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Pipeline::Chain::Skip, feature_category: :pipeline_composition do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:user) { create(:user) }
  let_it_be(:pipeline) { create(:ci_pipeline, project: project) }

  let(:command) do
    Gitlab::Ci::Pipeline::Chain::Command.new(
      project: project,
      current_user: user,
      ignore_skip_ci: false,
      save_incompleted: true)
  end

  let(:step) { described_class.new(pipeline, command) }

  describe '#skipped?' do
    shared_examples_for 'breaks the chain' do
      it 'breaks the chain' do
        expect(step.break?).to be true
      end
    end

    context 'when pipeline has not been skipped' do
      it 'does not break the chain' do
        expect(step.break?).to be false
      end
    end

    context 'when pipeline should be skipped' do
      before do
        allow(pipeline).to receive(:git_commit_message).and_return('commit message [ci skip]')
      end

      it_behaves_like 'breaks the chain'

      context 'when there are no pipeline execution policies defined' do
        before do
          command.pipeline_policy_context = instance_double(
            Gitlab::Ci::Pipeline::PipelineExecutionPolicies::PipelineContext,
            has_execution_policy_pipelines?: false
          )
        end

        it_behaves_like 'breaks the chain'
      end

      context 'when pipeline execution policies are not allowing skip' do
        before do
          command.pipeline_policy_context = instance_double(
            Gitlab::Ci::Pipeline::PipelineExecutionPolicies::PipelineContext,
            skip_ci_allowed?: false,
            has_execution_policy_pipelines?: true
          )
        end

        it 'does not break the chain' do
          expect(step.break?).to be false
        end
      end

      context 'when pipeline execution policies are allowing skip' do
        before do
          command.pipeline_policy_context = instance_double(
            Gitlab::Ci::Pipeline::PipelineExecutionPolicies::PipelineContext,
            skip_ci_allowed?: true,
            has_execution_policy_pipelines?: true
          )
        end

        it_behaves_like 'breaks the chain'
      end
    end
  end
end
