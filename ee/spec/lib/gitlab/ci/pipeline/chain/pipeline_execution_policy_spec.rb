# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Pipeline::Chain::PipelineExecutionPolicy, feature_category: :security_policy_management do
  let(:config) { build(:execution_policy_config) }
  let(:instance) { described_class.new(anything, config) }

  describe '#strategy_override_project_ci?' do
    subject { instance.strategy_override_project_ci? }

    it { is_expected.to be(false) }

    context 'when strategy is override_project_ci' do
      let(:config) { build(:execution_policy_config, :override_project_ci) }

      it { is_expected.to be(true) }
    end
  end

  describe '#suffix_on_conflict?' do
    subject { instance.suffix_on_conflict? }

    context 'when suffix_strategy is `never`' do
      let(:config) { build(:execution_policy_config, suffix_strategy: :never) }

      it { is_expected.to be(false) }
    end

    context 'when suffix_strategy is `on_conflict`' do
      let(:config) { build(:execution_policy_config, suffix_strategy: :on_conflict) }

      it { is_expected.to be(true) }
    end
  end
end
