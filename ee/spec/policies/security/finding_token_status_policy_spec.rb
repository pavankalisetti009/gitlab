# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::FindingTokenStatusPolicy, feature_category: :secret_detection do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:security_scan) { create(:security_scan, project: project, scan_type: :secret_detection) }
  let_it_be(:finding) { create(:security_finding, scan: security_scan) }
  let_it_be(:token_status) { create(:security_finding_token_status, security_finding: finding) }

  subject { described_class.new(user, token_status) }

  before do
    stub_licensed_features(security_dashboard: true)
  end

  context 'when user has project access' do
    before_all do
      project.add_developer(user)
    end

    context 'when both FFs are enabled' do
      before do
        stub_feature_flags(validity_checks: true)
        stub_feature_flags(validity_checks_security_finding_status: true)
      end

      it { is_expected.to be_allowed(:read_finding_token_status) }
    end

    context 'when validity_checks ff is disabled' do
      before do
        stub_feature_flags(validity_checks: false)
        stub_feature_flags(validity_checks_security_finding_status: true)
      end

      it { is_expected.to be_disallowed(:read_finding_token_status) }
    end

    context 'when validity_checks_security_finding_status ff is disabled' do
      before do
        stub_feature_flags(validity_checks: true)
        stub_feature_flags(validity_checks_security_finding_status: false)
      end

      it { is_expected.to be_disallowed(:read_finding_token_status) }
    end
  end

  context 'when user does not have project access' do
    before do
      stub_feature_flags(validity_checks: true)
      stub_feature_flags(validity_checks_security_finding_status: true)
    end

    it { is_expected.to be_disallowed(:read_finding_token_status) }
  end
end
