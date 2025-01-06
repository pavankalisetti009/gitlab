# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanExecutionPolicy::Config, feature_category: :security_policy_management do
  let(:config) { described_class.new(**params) }
  let(:params) { { policy: policy } }

  describe '#actions' do
    subject { config.actions }

    let(:policy) { build(:scan_execution_policy, actions: [{ scan: 'secret_detection' }]) }

    it { is_expected.to eq([{ scan: 'secret_detection' }]) }
  end
end
