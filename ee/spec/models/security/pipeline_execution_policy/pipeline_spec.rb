# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::PipelineExecutionPolicy::Pipeline, feature_category: :security_policy_management do
  let(:config) { build(:pipeline_execution_policy_config) }
  let(:instance) { described_class.new(pipeline: build(:ci_empty_pipeline), config: config) }

  describe '#strategy_override_project_ci?' do
    subject { instance.strategy_override_project_ci? }

    it { is_expected.to be(false) }

    context 'when strategy is override_project_ci' do
      let(:config) { build(:pipeline_execution_policy_config, :override_project_ci) }

      it { is_expected.to be(true) }
    end
  end

  describe '#suffix_on_conflict?' do
    subject { instance.suffix_on_conflict? }

    context 'when suffix_strategy is `never`' do
      let(:config) { build(:pipeline_execution_policy_config, :suffix_never) }

      it { is_expected.to be(false) }
    end

    context 'when suffix_strategy is `on_conflict`' do
      let(:config) { build(:pipeline_execution_policy_config, :suffix_on_conflict) }

      it { is_expected.to be(true) }
    end
  end
end
