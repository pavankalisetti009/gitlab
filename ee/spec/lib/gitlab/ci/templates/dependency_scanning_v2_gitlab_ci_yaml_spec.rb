# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Dependency-Scanning.v2.gitlab-ci.yml', feature_category: :software_composition_analysis do
  include Ci::PipelineMessageHelpers

  subject(:template) { Gitlab::Template::GitlabCiYmlTemplate.find('Jobs/Dependency-Scanning.v2') }

  describe 'the created pipeline' do
    let_it_be(:default_branch) { 'master' }
    let_it_be(:feature_branch) { 'patch-1' }
    let_it_be(:inputs) { {} }

    let(:pipeline) { service.execute(:push, inputs: inputs).payload }

    before do
      stub_ci_pipeline_yaml_file(template.content)
    end

    context "when included in any project" do
      include_context 'when project has files', ["any.file"]

      context 'as a branch pipeline on the default branch' do
        include_context 'with default branch pipeline setup'

        include_examples 'has expected jobs', %w[dependency-scanning]
      end

      context 'as a branch pipeline on a feature branch' do
        include_context 'with feature branch pipeline setup'

        include_examples 'has expected jobs', %w[dependency-scanning]
      end

      context 'as an MR pipeline' do
        include_context 'with MR pipeline setup'

        include_examples 'has expected jobs', %w[dependency-scanning]

        context 'with MR pipelines explicitly disabled via variable' do
          include_context 'with CI variables', { 'AST_ENABLE_MR_PIPELINES' => 'false' }

          include_examples 'has expected jobs', %w[]
        end
      end
    end

    context 'when job name is specified' do
      include_context 'when project has files', ["any.file"]
      include_context 'with default branch pipeline setup'

      let(:inputs) { { job_name: 'dependency-scanning-1a' } }

      include_examples 'has expected jobs', %w[dependency-scanning-1a]
    end

    context 'when inputs for job configuration are set' do
      include_context 'when project has files', ["any.file"]
      include_context 'with default branch pipeline setup'

      let(:ds_job) { pipeline.builds.find_by(name: 'dependency-scanning') }

      context 'and job stage is specified' do
        let(:inputs) { { stage: 'build' } }

        it 'matches' do
          expect(ds_job.stage).to eq('build')
        end
      end

      context 'and failure mode is specified' do
        let(:inputs) { { allow_failure: false } }

        it 'matches' do
          expect(ds_job.allow_failure).to be(false)
        end
      end

      context 'and analyzer image inputs are specified' do
        using RSpec::Parameterized::TableSyntax

        where do
          {
            'default' => {
              variables: {},
              inputs: {},
              expected_analyzer_image: 'registry.gitlab.com/security-products/dependency-scanning:1'
            },
            'set prefix' => {
              variables: {},
              inputs: {
                analyzer_image_prefix: 'registry.example.com'
              },
              expected_analyzer_image: 'registry.example.com/dependency-scanning:1'
            },
            'set name' => {
              variables: {},
              inputs: {
                analyzer_image_name: 'foo'
              },
              expected_analyzer_image: 'registry.gitlab.com/security-products/foo:1'
            },
            'set version' => {
              variables: {},
              inputs: {
                analyzer_image_version: '0'
              },
              expected_analyzer_image: 'registry.gitlab.com/security-products/dependency-scanning:0'
            },
            'set all' => {
              variables: {},
              inputs: {
                analyzer_image_prefix: 'registry.example.com/security',
                analyzer_image_name: 'bar',
                analyzer_image_version: 'v9.8.7'
              },
              expected_analyzer_image: 'registry.example.com/security/bar:v9.8.7'
            },
            'SECURE_ANALYZERS_PREFIX is set' => {
              variables: {
                SECURE_ANALYZERS_PREFIX: "registry.other.com/appsec-team"
              },
              inputs: {
                analyzer_image_name: 'bar',
                analyzer_image_version: 'v9.8.7'
              },
              expected_analyzer_image: 'registry.other.com/appsec-team/bar:v9.8.7'
            }
          }
        end

        with_them do
          include_context 'with CI variables', params[:variables]
          include_examples 'has expected image', 'dependency-scanning', params[:expected_analyzer_image]
        end
      end
    end
  end
end
