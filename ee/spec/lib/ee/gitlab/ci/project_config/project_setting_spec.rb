# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::ProjectConfig::ProjectSetting, feature_category: :continuous_integration do
  let_it_be(:project) { create(:project, :custom_repo, files: { '.gitlab-ci.yml' => '# CI' }) }

  let(:sha) { project.repository.head_commit.sha }
  let(:has_overriding_execution_policy_pipelines) { false }

  let(:pipeline_policy_context) do
    Gitlab::Ci::Pipeline::PipelineExecutionPolicies::PipelineContext.new(project: project)
  end

  let(:config_content_result) do
    <<~CICONFIG
    ---
    include:
    - local: ".gitlab-ci.yml"
    CICONFIG
  end

  let(:config) do
    described_class.new(
      project: project,
      sha: sha,
      pipeline_policy_context: pipeline_policy_context
    )
  end

  before do
    allow(pipeline_policy_context).to(
      receive(:has_overriding_execution_policy_pipelines?).and_return(has_overriding_execution_policy_pipelines)
    )
  end

  describe '#content' do
    subject { config.content }

    it { is_expected.to eq(config_content_result) }

    context 'when it has overriding pipeline execution policies' do
      let(:has_overriding_execution_policy_pipelines) { true }

      it { is_expected.to be_nil }
    end
  end
end
