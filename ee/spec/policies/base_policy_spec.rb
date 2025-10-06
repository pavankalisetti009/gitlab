# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BasePolicy do
  include ExternalAuthorizationServiceHelpers
  include AdminModeHelper

  let(:auditor) { build(:auditor) }

  subject { described_class.new(auditor, nil) }

  describe 'read cross project' do
    context 'when an external authorization service is enabled' do
      before do
        enable_external_authorization_service_check
      end

      it 'allows auditors' do
        is_expected.to be_allowed(:read_cross_project)
      end
    end
  end

  describe 'read all resources' do
    it 'allows auditors' do
      is_expected.to be_allowed(:read_all_resources)
    end
  end

  describe 'admin all resources' do
    it 'forbids auditors' do
      is_expected.to be_disallowed(:admin_all_resources)
    end
  end

  describe ':read_subscription_usage', feature_category: :consumables_cost_management do
    let(:user) { build_stubbed(:user) }
    let(:admin) { build_stubbed(:admin) }

    it { expect(described_class.new(user, nil)).to be_disallowed(:read_subscription_usage) }
    it { expect(described_class.new(admin, nil)).to be_disallowed(:read_subscription_usage) }

    context 'when in admin mode' do
      before do
        enable_admin_mode!(user)
        enable_admin_mode!(admin)
      end

      it { expect(described_class.new(user, nil)).to be_disallowed(:read_subscription_usage) }
      it { expect(described_class.new(admin, nil)).to be_allowed(:read_subscription_usage) }
    end
  end
end
