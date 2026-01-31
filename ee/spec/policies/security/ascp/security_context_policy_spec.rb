# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Ascp::SecurityContextPolicy, feature_category: :static_application_security_testing do
  describe 'read_ascp_security_context' do
    let(:user) { create(:user) }
    let(:security_context) { create(:security_ascp_security_context) }

    subject { described_class.new(user, security_context) }

    context 'when the security_dashboard feature is enabled' do
      before do
        stub_licensed_features(security_dashboard: true)
      end

      context 'when the current user is not a project member' do
        it { is_expected.to be_disallowed(:read_ascp_security_context) }
      end

      context 'when the current user has developer access' do
        before do
          security_context.project.add_developer(user)
        end

        it { is_expected.to be_allowed(:read_ascp_security_context) }
      end
    end

    context 'when the security_dashboard feature is disabled' do
      before do
        stub_licensed_features(security_dashboard: false)
        security_context.project.add_developer(user)
      end

      it { is_expected.to be_disallowed(:read_ascp_security_context) }
    end
  end
end
