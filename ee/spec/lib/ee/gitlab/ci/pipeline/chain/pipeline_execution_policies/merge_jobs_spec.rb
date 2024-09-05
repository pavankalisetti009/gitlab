# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Pipeline::Chain::PipelineExecutionPolicies::MergeJobs, feature_category: :security_policy_management do
  include Ci::PipelineExecutionPolicyHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :repository, group: group) }
  let_it_be(:user) { create(:user, developer_of: project) }
  let(:pipeline) { build(:ci_pipeline, project: project, ref: 'master', user: user) }

  let(:execution_policy_pipelines) do
    [
      build(:pipeline_execution_policy_pipeline, pipeline: build_mock_policy_pipeline({ 'build' => ['docker'] })),
      build(:pipeline_execution_policy_pipeline, pipeline: build_mock_policy_pipeline({ 'test' => ['rspec'] }))
    ]
  end

  let(:command) do
    Gitlab::Ci::Pipeline::Chain::Command.new(
      project: project,
      current_user: user,
      origin_ref: pipeline.ref,
      execution_policy_pipelines: execution_policy_pipelines
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
    it 'reassigns jobs to the correct stage', :aggregate_failures do
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

    it 'marks the jobs as execution_policy_jobs' do
      run_chain

      test_stage = pipeline.stages.find { |stage| stage.name == 'test' }
      project_rake_job = test_stage.statuses.find { |status| status.name == 'rake' }
      policy_rspec_job = test_stage.statuses.find { |status| status.name == 'rspec' }

      expect(project_rake_job.execution_policy_job?).to eq(false)
      expect(policy_rspec_job.execution_policy_job?).to eq(true)
    end

    context 'with conflicting jobs' do
      let(:conflicting_job_script) { 'echo "job with suffix"' }
      let(:non_conflicting_job_script) { 'echo "job without suffix"' }

      shared_examples_for 'merges both jobs using suffix for conflicts' do |job_name|
        it 'keeps both jobs, appending suffix to the conflicting job name', :aggregate_failures do
          run_chain

          test_stage = pipeline.stages.find { |stage| stage.name == 'test' }
          expect(test_stage.statuses.map(&:name)).to contain_exactly('rake', 'rspec', "#{job_name}:policy-123456-0")

          first_policy_rspec_job = test_stage.statuses.find { |status| status.name == 'rspec' }
          expect(first_policy_rspec_job.options[:script]).to eq non_conflicting_job_script

          second_policy_rspec_job = test_stage.statuses.find { |status| status.name == "#{job_name}:policy-123456-0" }
          expect(second_policy_rspec_job.options[:script]).to eq conflicting_job_script
        end

        it 'does not break the processing chain' do
          run_chain

          expect(step.break?).to be false
        end
      end

      shared_examples_for 'results in duplicate job error' do |job_name|
        it 'results in duplicate job error' do
          run_chain

          expect(pipeline.errors[:base])
            .to contain_exactly("Pipeline execution policy error: job names must be unique (#{job_name})")
        end

        it 'breaks the processing chain' do
          run_chain

          expect(step.break?).to be true
        end
      end

      context 'when two policy pipelines have the same job names' do
        let(:execution_policy_pipelines) do
          [
            build(:pipeline_execution_policy_pipeline, pipeline: build_mock_policy_pipeline({ 'test' => ['rspec'] }),
              job_script: non_conflicting_job_script),
            build(:pipeline_execution_policy_pipeline, pipeline: build_mock_policy_pipeline({ 'test' => ['rspec'] }),
              job_script: conflicting_job_script)
          ]
        end

        it_behaves_like 'merges both jobs using suffix for conflicts', 'rspec'

        context 'when jobs contain `needs`' do
          let(:execution_policy_pipelines) do
            [
              build(:pipeline_execution_policy_pipeline,
                pipeline: build_mock_policy_pipeline({ 'test' => ['rspec'], 'deploy' => ['check-needs-rspec'] }),
                job_script: non_conflicting_job_script),
              build(:pipeline_execution_policy_pipeline,
                pipeline: build_mock_policy_pipeline(
                  { 'test' => %w[rspec jest], 'deploy' => %w[check-needs-rspec coverage-needs-jest] }
                ),
                job_script: conflicting_job_script)
            ]
          end

          before do
            policy1_stages = execution_policy_pipelines.first.pipeline.stages
            policy1_rspec = policy1_stages.first.statuses.find { |job| job.name == 'rspec' }
            build_job_needs(job: policy1_stages.last.statuses.first, needs: policy1_rspec)

            policy2_stages = execution_policy_pipelines.last.pipeline.stages
            policy2_rspec = policy2_stages.first.statuses.find { |job| job.name == 'rspec' }
            policy2_jest = policy2_stages.first.statuses.find { |job| job.name == 'jest' }
            build_job_needs(job: policy2_stages.last.statuses.first, needs: policy2_rspec)
            build_job_needs(job: policy2_stages.last.statuses.last, needs: policy2_jest)
          end

          it 'updates references in job `needs` per policy pipeline', :aggregate_failures do
            run_chain

            expect(get_stage_jobs(pipeline, 'test'))
              .to contain_exactly('rake', 'rspec', 'rspec:policy-123456-0', 'jest')
            expect(get_stage_jobs(pipeline, 'deploy'))
              .to contain_exactly('check-needs-rspec', 'check-needs-rspec:policy-123456-0', 'coverage-needs-jest')

            expect(get_job_needs(pipeline, 'deploy', 'check-needs-rspec')).to contain_exactly('rspec')
            expect(get_job_needs(pipeline, 'deploy', 'check-needs-rspec:policy-123456-0'))
              .to contain_exactly('rspec:policy-123456-0')
            expect(get_job_needs(pipeline, 'deploy', 'coverage-needs-jest')).to contain_exactly('jest')
          end
        end

        context 'when feature flag "pipeline_execution_policy_suffix" is disabled' do
          before do
            stub_feature_flags(pipeline_execution_policy_suffix: false)
          end

          it_behaves_like 'results in duplicate job error', 'rspec'
        end

        context 'when suffix is set to "never"' do
          let(:execution_policy_pipelines) do
            [
              build(:pipeline_execution_policy_pipeline, :suffix_never,
                pipeline: build_mock_policy_pipeline({ 'test' => ['rspec'] })),
              build(:pipeline_execution_policy_pipeline, :suffix_never,
                pipeline: build_mock_policy_pipeline({ 'test' => ['rspec'] }))
            ]
          end

          it_behaves_like 'results in duplicate job error', 'rspec'
        end
      end

      context 'when project and policy pipelines have the same job names' do
        let(:execution_policy_pipelines) do
          [
            build(:pipeline_execution_policy_pipeline, pipeline: build_mock_policy_pipeline({ 'test' => ['rake'] }),
              job_script: conflicting_job_script),
            build(:pipeline_execution_policy_pipeline, pipeline: build_mock_policy_pipeline({ 'test' => ['rspec'] }),
              job_script: non_conflicting_job_script)
          ]
        end

        it_behaves_like 'merges both jobs using suffix for conflicts', 'rake'

        context 'when feature flag "pipeline_execution_policy_suffix" is disabled' do
          before do
            stub_feature_flags(pipeline_execution_policy_suffix: false)
          end

          it_behaves_like 'results in duplicate job error', 'rake'
        end

        context 'when suffix is set to "never"' do
          context 'when a policy with duplicate job uses "never" suffix' do
            let(:execution_policy_pipelines) do
              [
                build(:pipeline_execution_policy_pipeline, :suffix_never,
                  pipeline: build_mock_policy_pipeline({ 'test' => ['rake'] })),
                build(:pipeline_execution_policy_pipeline,
                  pipeline: build_mock_policy_pipeline({ 'test' => ['rspec'] }))
              ]
            end

            it_behaves_like 'results in duplicate job error', 'rake'
          end
        end

        context 'when other policy uses "never" strategy' do
          let(:execution_policy_pipelines) do
            [
              build(:pipeline_execution_policy_pipeline,
                pipeline: build_mock_policy_pipeline({ 'test' => ['rake'] }), job_script: conflicting_job_script),
              build(:pipeline_execution_policy_pipeline, :suffix_never,
                pipeline: build_mock_policy_pipeline({ 'test' => ['rspec'] }), job_script: non_conflicting_job_script)
            ]
          end

          it_behaves_like 'merges both jobs using suffix for conflicts', 'rake'
        end
      end
    end

    context 'when policy defines additional stages' do
      context 'when custom policy stage is also defined but not used in the main pipeline' do
        let(:config) do
          { stages: %w[build test custom],
            rake: { stage: 'test', script: 'rake' } }
        end

        let(:execution_policy_pipelines) do
          build_list(:pipeline_execution_policy_pipeline, 1,
            pipeline: build_mock_policy_pipeline({ 'custom' => ['docker'] }))
        end

        it 'injects the policy job into the custom stage', :aggregate_failures do
          run_chain

          expect(pipeline.stages.map(&:name)).to contain_exactly('test', 'custom')

          custom_stage = pipeline.stages.find { |stage| stage.name == 'custom' }
          expect(custom_stage.position).to eq(4)
          expect(custom_stage.statuses.map(&:name)).to contain_exactly('docker')
        end

        it_behaves_like 'internal event tracking' do
          let(:event) { 'execute_job_pipeline_execution_policy' }
          let(:category) { described_class.name }
          let_it_be(:project) { project }
          let_it_be(:user) { nil }
          let_it_be(:namespace) { project.group }
        end

        context 'when the policy has multiple jobs' do
          let(:execution_policy_pipelines) do
            build_list(:pipeline_execution_policy_pipeline, 1,
              pipeline: build_mock_policy_pipeline({ 'custom' => %w[docker rspec] }))
          end

          it 'triggers one event per job' do
            expect { run_chain }.to trigger_internal_events('execute_job_pipeline_execution_policy')
                                    .with(category: described_class.name,
                                      project: project,
                                      namespace:  project.group)
                                    .exactly(2).times
          end
        end
      end

      context 'when custom policy stage is not defined in the main pipeline' do
        let(:execution_policy_pipelines) do
          build_list(:pipeline_execution_policy_pipeline, 1,
            pipeline: build_mock_policy_pipeline({ 'custom' => ['docker'] }))
        end

        it 'ignores the stage' do
          run_chain

          expect(pipeline.stages.map(&:name)).to contain_exactly('build', 'test')
        end

        it_behaves_like 'internal event not tracked' do
          let(:event) { 'execute_job_pipeline_execution_policy' }
        end
      end
    end

    context 'when the policy stage is defined in a different position than the stage in the main pipeline' do
      let(:config) do
        { stages: %w[build test],
          rake: { stage: 'test', script: 'rake' } }
      end

      let(:execution_policy_pipelines) do
        build_list(:pipeline_execution_policy_pipeline, 1,
          pipeline: build_mock_policy_pipeline({ 'test' => ['rspec'] }))
      end

      it 'reassigns the position and stage_idx for the jobs to match the main pipeline', :aggregate_failures do
        run_chain

        test_stage = pipeline.stages.find { |stage| stage.name == 'test' }
        expect(test_stage.position).to eq(3)
        expect(test_stage.statuses.map(&:name)).to contain_exactly('rake', 'rspec')
        expect(test_stage.statuses.map(&:stage_idx)).to all(eq(test_stage.position))
      end
    end

    context 'when there are gaps in the main pipeline stages due to them being unused' do
      let(:config) do
        { stages: %w[build test deploy],
          package: { stage: 'deploy', script: 'package' } }
      end

      let(:execution_policy_pipelines) do
        build_list(:pipeline_execution_policy_pipeline, 1,
          pipeline: build_mock_policy_pipeline({ 'deploy' => ['docker'] }))
      end

      it 'reassigns the position and stage_idx for policy jobs based on the declared stages', :aggregate_failures do
        run_chain

        expect(pipeline.stages.map(&:name)).to contain_exactly('deploy')

        deploy_stage = pipeline.stages.find { |stage| stage.name == 'deploy' }
        expect(deploy_stage.position).to eq(4)
        expect(deploy_stage.statuses.map(&:name)).to contain_exactly('package', 'docker')
        expect(deploy_stage.statuses.map(&:stage_idx)).to all(eq(deploy_stage.position))
      end
    end

    context 'when there is no project CI configuration' do
      let(:config) { nil }

      it 'removes the dummy job that forced the pipeline creation and only keeps policy jobs in default stages' do
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

      let(:execution_policy_pipelines) do
        [
          build(
            :pipeline_execution_policy_pipeline, :override_project_ci,
            pipeline: build_mock_policy_pipeline({ '.pipeline-policy-pre' => ['rspec'] })
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

    context 'when execution_policy_pipelines is not defined' do
      let(:execution_policy_pipelines) { nil }

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
