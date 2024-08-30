# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::PipelineExecutionPolicy, feature_category: :security_policy_management do
  describe '.build_policy_suffix' do
    subject { described_class.build_policy_suffix(**params) }

    let(:params) { { policy_project_id: 123, policy_index: 1, policy: policy } }

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
