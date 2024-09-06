# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::PipelineExecutionPolicy::Config, feature_category: :security_policy_management do
  let(:config) { described_class.new(**params) }
  let(:params) { { policy_project_id: 123, policy_index: 1, policy: policy } }

  describe '#suffix' do
    subject { config.suffix }

    context 'when policy has suffix "on_conflict"' do
      let(:policy) { build(:pipeline_execution_policy, suffix: 'on_conflict') }

      it { is_expected.to eq ':policy-123-1' }
    end

    context 'when policy has no suffix specified' do
      let(:policy) { build(:pipeline_execution_policy, suffix: nil) }

      it { is_expected.to eq ':policy-123-1' }
    end

    context 'when policy has suffix "never"' do
      let(:policy) { build(:pipeline_execution_policy, suffix: 'never') }

      it { is_expected.to be_nil }
    end
  end
end
