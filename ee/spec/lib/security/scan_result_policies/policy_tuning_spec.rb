# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::PolicyTuning, feature_category: :security_policy_management do
  let(:policy_tuning_data) do
    {
      security_report_time_window: 1440
    }
  end

  subject(:policy_tuning) { described_class.new(policy_tuning_data) }

  describe '#security_report_time_window' do
    context 'when security_report_time_window is present' do
      it 'returns the security_report_time_window value' do
        expect(policy_tuning.security_report_time_window).to eq(1440)
      end
    end

    context 'when security_report_time_window is nil' do
      let(:policy_tuning_data) { {} }

      it 'returns nil' do
        expect(policy_tuning.security_report_time_window).to be_nil
      end
    end
  end
end
