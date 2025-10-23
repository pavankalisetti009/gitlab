# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::PipelineProcessing::ReservedStageStatusCalculationService, '#execute', feature_category: :continuous_integration do
  using RSpec::Parameterized::TableSyntax
  let_it_be(:project) { create(:project, :repository) }
  let_it_be_with_reload(:pipeline) { create(:ci_empty_pipeline, ref: 'master', project: project) }

  let(:collection) { instance_double(Ci::PipelineProcessing::AtomicProcessingService::StatusCollection) }
  let(:job) { create(:ci_build, :created, name: 'test', pipeline: pipeline) }

  subject(:execute) { described_class.new(pipeline, collection, job).execute }

  context 'when pipeline has no reserved pre stage' do
    it { is_expected.to be_nil }
  end

  context 'when pipeline has a reserved pre stage' do
    let_it_be(:test_stage) { create(:ci_stage, pipeline: pipeline, name: 'test', position: 1) }
    let_it_be_with_reload(:reserved_pre_stage) do
      create(:ci_stage, pipeline: pipeline, name: '.pipeline-policy-pre', position: 0)
    end

    context 'when job is not on the reserved pre stage' do
      where(:pre_stage_status, :scheduling_type, :experiment_enabled, :result) do
        'running' | 'stage' | false | nil
        'running' | 'dag' | false | 'running'
        'success' | 'stage' | false | nil
        'success' | 'dag' | false | nil
        'failed' | 'stage' | false | nil
        'failed' | 'dag' | false | nil
        'running' | 'stage' | true | 'running'
        'running' | 'dag' | true | 'running'
        'success' | 'stage' | true | nil
        'success' | 'dag' | true | nil
        'failed' | 'stage' | true | 'canceled'
        'failed' | 'dag' | true | 'canceled'
      end

      with_them do
        before do
          allow(collection)
            .to receive(:status_of_stage).with(reserved_pre_stage.position).and_return(pre_stage_status)
        end

        let!(:policy_job) do
          create(:ci_build, :created,
            name: 'policy_job',
            pipeline: pipeline,
            ci_stage: reserved_pre_stage,
            options: { policy: { pre_succeeds: experiment_enabled } })
        end

        context 'when job is on the reserved pre stage' do
          let(:job) do
            create(:ci_build, :created,
              name: 'test',
              pipeline: pipeline,
              scheduling_type: scheduling_type,
              ci_stage: reserved_pre_stage)
          end

          it { is_expected.to be_nil }
        end

        context 'when job is not on the reserved pre stage' do
          let(:job) do
            create(:ci_build, :created,
              name: 'test',
              pipeline: pipeline,
              scheduling_type: scheduling_type,
              ci_stage: test_stage)
          end

          it { is_expected.to eq(result) }

          # TODO: Remove with https://gitlab.com/gitlab-org/gitlab/-/issues/577272
          context 'when the policy job uses options in the old format' do
            let!(:policy_job) do
              create(:ci_build, :created,
                name: 'policy_job',
                pipeline: pipeline,
                ci_stage: reserved_pre_stage,
                options: { execution_policy_pre_succeeds: experiment_enabled })
            end

            it { is_expected.to eq(result) }
          end
        end
      end
    end
  end
end
