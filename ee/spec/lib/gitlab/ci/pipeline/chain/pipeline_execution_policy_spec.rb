# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Pipeline::Chain::PipelineExecutionPolicy, feature_category: :security_policy_management do
  describe '#strategy_override_project_ci?' do
    subject { described_class.new(anything, strategy).strategy_override_project_ci? }

    let(:strategy) { anything }

    it { is_expected.to be(false) }

    context 'when strategy is override_project_ci' do
      let(:strategy) { :override_project_ci }

      it { is_expected.to be(true) }
    end
  end
end
