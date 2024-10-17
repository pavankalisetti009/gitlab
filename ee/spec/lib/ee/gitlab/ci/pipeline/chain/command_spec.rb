# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Pipeline::Chain::Command, feature_category: :continuous_integration do
  let_it_be(:project) { create(:project, :repository) }

  describe '#execution_policy_mode?', feature_category: :security_policy_management do
    subject { command.execution_policy_mode? }

    let(:command) { described_class.new(project: project, execution_policy_dry_run: execution_policy_dry_run) }
    let(:execution_policy_dry_run) { true }

    it { is_expected.to eq(true) }

    context 'when execution_policy_dry_run is nil' do
      let(:execution_policy_dry_run) { nil }

      it { is_expected.to eq(false) }
    end
  end

  describe '#increment_duplicate_job_name_errors_counter' do
    let(:command) { described_class.new }
    let(:suffix_strategy) { 'never' }

    subject(:increment) { command.increment_duplicate_job_name_errors_counter(suffix_strategy) }

    it 'increments the error metric' do
      counter = Gitlab::Metrics.counter(:gitlab_ci_duplicate_job_name_errors_counter, 'desc')
      expect { increment }.to change { counter.get(suffix_strategy: suffix_strategy) }.by(1)
    end
  end
end
