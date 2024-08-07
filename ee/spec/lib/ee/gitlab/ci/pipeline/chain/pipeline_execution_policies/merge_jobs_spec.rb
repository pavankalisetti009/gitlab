# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Pipeline::Chain::PipelineExecutionPolicies::MergeJobs, feature_category: :security_policy_management do
  include Ci::PipelineExecutionPolicyHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :repository, group: group) }
  let_it_be(:user) { create(:user, developer_of: project) }
  let(:pipeline) { build(:ci_pipeline, project: project, ref: 'master', user: user) }

  let(:pipeline_execution_policies) do
    [
      build(:ci_pipeline_execution_policy, pipeline: build_mock_policy_pipeline({ 'build' => ['docker'] })),
      build(:ci_pipeline_execution_policy, pipeline: build_mock_policy_pipeline({ 'test' => ['rspec'] }))
    ]
  end

  let(:command) do
    Gitlab::Ci::Pipeline::Chain::Command.new(
      project: project,
      current_user: user,
      origin_ref: pipeline.ref,
      pipeline_execution_policies: pipeline_execution_policies
    )
  end

  let(:step) { described_class.new(pipeline, command) }

  let(:config) do
    { build_job: { stage: 'build', script: 'docker build .' },
      rake: { stage: 'test', script: 'rake' } }
  end

  subject(:run_chain) do
    run_previous_chain(pipeline, command)
    perform_chain(pipeline, command)
  end

  before do
    stub_ci_pipeline_yaml_file(YAML.dump(config)) if config
  end

  describe '#perform!' do
    it 'reassigns jobs to the correct stage using JobsMerger', :aggregate_failures do
      expect(::Gitlab::Ci::Pipeline::PipelineExecutionPolicies::JobsMerger)
        .to receive(:new).with(
          pipeline: pipeline,
          pipeline_execution_policies: pipeline_execution_policies,
          declared_stages: %w[.pipeline-policy-pre .pre build test deploy .post .pipeline-policy-post]
        ).and_call_original

      run_chain

      build_stage = pipeline.stages.find { |stage| stage.name == 'build' }
      expect(build_stage.statuses.map(&:name)).to contain_exactly('build_job', 'docker')

      test_stage = pipeline.stages.find { |stage| stage.name == 'test' }
      expect(test_stage.statuses.map(&:name)).to contain_exactly('rake', 'rspec')
    end

    it_behaves_like 'internal event tracking' do
      let(:event) { 'enforce_pipeline_execution_policy_in_project' }
      let(:category) { described_class.name }
      let_it_be(:project) { project }
      let_it_be(:user) { nil }
      let_it_be(:namespace) { group }
    end

    context 'when project CI configuration declares custom stages' do
      let(:config) do
        { stages: %w[pre-test test post-test],
          rake: { stage: 'test', script: 'rake' } }
      end

      it 'passes down the declared stages to the JobsMerger' do
        expect(::Gitlab::Ci::Pipeline::PipelineExecutionPolicies::JobsMerger)
          .to receive(:new).with(
            pipeline: pipeline,
            pipeline_execution_policies: pipeline_execution_policies,
            declared_stages: %w[.pipeline-policy-pre .pre pre-test test post-test .post .pipeline-policy-post]
          ).and_call_original

        run_chain
      end

      it_behaves_like 'internal event tracking' do
        let(:event) { 'enforce_pipeline_execution_policy_in_project' }
        let(:category) { described_class.name }
        let_it_be(:project) { project }
        let_it_be(:user) { nil }
        let_it_be(:namespace) { group }
      end
    end

    context 'when job names are not unique' do
      let(:config) do
        { rspec: { stage: 'test', script: 'rspec' } }
      end

      before do
        run_chain
      end

      it 'propagates the error to the pipeline' do
        expect(pipeline.errors[:base])
          .to contain_exactly('Pipeline execution policy error: job names must be unique (rspec)')
      end

      it 'breaks the processing chain' do
        expect(step.break?).to be true
      end

      it 'does not save the pipeline' do
        expect(pipeline).not_to be_persisted
      end
    end

    context 'when there is no project CI configuration' do
      let(:config) { nil }

      it 'removes the dummy job that forced the pipeline creation and only keeps policy jobs in default stages' do
        expect(::Gitlab::Ci::Pipeline::PipelineExecutionPolicies::JobsMerger)
          .to receive(:new).with(
            pipeline: pipeline,
            pipeline_execution_policies: pipeline_execution_policies,
            declared_stages: %w[.pipeline-policy-pre .pre build test deploy .post .pipeline-policy-post]
          ).and_call_original

        run_chain

        expect(pipeline.stages.map(&:name)).to contain_exactly('build', 'test')

        build_stage = pipeline.stages.find { |stage| stage.name == 'build' }
        expect(build_stage.statuses.map(&:name)).to contain_exactly('docker')

        test_stage = pipeline.stages.find { |stage| stage.name == 'test' }
        expect(test_stage.statuses.map(&:name)).to contain_exactly('rspec')
      end

      it_behaves_like 'internal event tracking' do
        let(:event) { 'enforce_pipeline_execution_policy_in_project' }
        let(:category) { described_class.name }
        let_it_be(:project) { project }
        let_it_be(:user) { nil }
        let_it_be(:namespace) { group }
      end
    end

    context 'when a policy has strategy "override_project_ci"' do
      let(:config) do
        { rake: { script: 'rake' } }
      end

      let(:pipeline_execution_policies) do
        [
          build(
            :ci_pipeline_execution_policy,
            pipeline: build_mock_policy_pipeline({ '.pipeline-policy-pre' => ['rspec'] }),
            strategy: :override_project_ci
          )
        ]
      end

      it 'clears the project CI and injects the policy jobs' do
        run_chain

        expect(pipeline.stages).to be_one
        pre_stage = pipeline.stages.find { |stage| stage.name == '.pipeline-policy-pre' }
        expect(pre_stage.statuses.map(&:name)).to contain_exactly('rspec')
      end

      it_behaves_like 'internal event tracking' do
        let(:event) { 'enforce_pipeline_execution_policy_in_project' }
        let(:category) { described_class.name }
        let_it_be(:project) { project }
        let_it_be(:user) { nil }
        let_it_be(:namespace) { group }
      end
    end

    context 'when pipeline_execution_policies is not defined' do
      let(:pipeline_execution_policies) { nil }

      it 'does not change pipeline stages' do
        expect { run_chain }.not_to change { pipeline.stages }
      end

      it_behaves_like 'internal event not tracked' do
        let(:event) { 'enforce_pipeline_execution_policy_in_project' }
      end
    end

    private

    def run_previous_chain(pipeline, command)
      [
        Gitlab::Ci::Pipeline::Chain::Config::Content.new(pipeline, command),
        Gitlab::Ci::Pipeline::Chain::Config::Process.new(pipeline, command),
        Gitlab::Ci::Pipeline::Chain::EvaluateWorkflowRules.new(pipeline, command),
        Gitlab::Ci::Pipeline::Chain::Seed.new(pipeline, command),
        Gitlab::Ci::Pipeline::Chain::Populate.new(pipeline, command)
      ].map(&:perform!)
    end

    def perform_chain(pipeline, command)
      described_class.new(pipeline, command).perform!
    end
  end
end
