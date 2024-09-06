# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Pipeline::PipelineExecutionPolicies::PipelineContext, feature_category: :security_policy_management do
  subject(:context) { described_class.new(project: project, command: command) }

  include_context 'with pipeline policy context'

  describe '#execution_policy_mode?' do
    subject { context.execution_policy_mode? }

    it { is_expected.to eq(false) }

    context 'with execution_policy_dry_run' do
      let(:execution_policy_dry_run) { true }

      it { is_expected.to eq(true) }
    end

    context 'when command is nil' do
      let(:command) { nil }

      it { is_expected.to eq(false) }
    end
  end

  describe '#has_execution_policy_pipelines?' do
    subject { context.has_execution_policy_pipelines? }

    it { is_expected.to eq(false) }

    context 'with execution_policy_pipelines' do
      let(:execution_policy_pipelines) { build_list(:pipeline_execution_policy_pipeline, 2) }

      it { is_expected.to eq(true) }
    end

    context 'when command is nil' do
      let(:command) { nil }

      it { is_expected.to eq(false) }
    end
  end

  describe '#has_overriding_execution_policy_pipelines?' do
    subject { context.has_overriding_execution_policy_pipelines? }

    it { is_expected.to eq(false) }

    context 'with execution_policy_pipelines' do
      let(:execution_policy_pipelines) { build_list(:pipeline_execution_policy_pipeline, 2) }

      it { is_expected.to eq(false) }

      context 'and overriding execution_policy_pipelines' do
        let(:execution_policy_pipelines) { build_list(:pipeline_execution_policy_pipeline, 2, :override_project_ci) }

        it { is_expected.to eq(true) }
      end
    end
  end

  describe '#inject_policy_reserved_stages?' do
    subject { context.inject_policy_reserved_stages? }

    it { is_expected.to eq(false) }

    context 'with execution_policy_dry_run' do
      let(:execution_policy_dry_run) { true }

      it { is_expected.to eq(true) }
    end

    context 'with execution_policy_pipelines' do
      let(:execution_policy_pipelines) { build_list(:ci_empty_pipeline, 2) }

      it { is_expected.to eq(true) }
    end
  end

  describe '#valid_stage?' do
    subject { context.valid_stage?(stage) }

    let(:stage) { 'test' }

    it { is_expected.to eq(true) }

    %w[.pipeline-policy-pre .pipeline-policy-post].each do |stage|
      context "when stage is #{stage}" do
        let(:stage) { stage }

        it { is_expected.to eq(false) }

        context 'with execution_policy_dry_run' do
          let(:execution_policy_dry_run) { true }

          it { is_expected.to eq(true) }
        end
      end
    end
  end
end
