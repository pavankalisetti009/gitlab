# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Organizations::OrganizationPolicy, feature_category: :system_access do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:current_user) { create(:user) }

  subject(:policy) { described_class.new(current_user, organization) }

  RSpec.shared_context 'with licensed features' do |features|
    before do
      stub_licensed_features(features)
    end
  end

  context 'when the user is an admin' do
    let_it_be(:current_user) { create(:user, :admin) }

    context 'when admin mode is enabled', :enable_admin_mode do
      context 'when dependency scanning is enabled' do
        include_context 'with licensed features', dependency_scanning: true

        it { is_expected.to be_allowed(:read_dependency) }
      end

      context 'when license scanning is enabled' do
        include_context 'with licensed features', license_scanning: true

        it { is_expected.to be_allowed(:read_licenses) }
      end

      it { is_expected.to be_disallowed(:read_dependency) }
      it { is_expected.to be_disallowed(:read_licenses) }
    end

    context 'when admin mode is disabled' do
      it { is_expected.to be_disallowed(:read_dependency) }
      it { is_expected.to be_disallowed(:read_licenses) }
    end
  end

  context 'when the user is an organization owner' do
    let_it_be(:organization_user) { create(:organization_user, :owner, organization: organization, user: current_user) }

    context 'when dependency scanning is enabled' do
      include_context 'with licensed features', dependency_scanning: true

      it { is_expected.to be_allowed(:read_dependency) }
    end

    context 'when license scanning is enabled' do
      include_context 'with licensed features', license_scanning: true

      it { is_expected.to be_allowed(:read_licenses) }
    end

    it { is_expected.to be_disallowed(:read_dependency) }
    it { is_expected.to be_disallowed(:read_licenses) }
  end

  context 'when the user is an organization guest' do
    let_it_be(:organization_user) do
      create(:organization_user, organization: organization, user: current_user, access_level: :default)
    end

    context 'when dependency scanning is enabled' do
      include_context 'with licensed features', dependency_scanning: true

      it { is_expected.to be_allowed(:read_dependency) }
    end

    context 'when license scanning is enabled' do
      include_context 'with licensed features', license_scanning: true

      it { is_expected.to be_allowed(:read_licenses) }
    end

    it { is_expected.to be_disallowed(:read_dependency) }
    it { is_expected.to be_disallowed(:read_licenses) }
  end

  context 'when the user is not a member of the organization' do
    it { is_expected.to be_disallowed(:read_dependency) }
    it { is_expected.to be_disallowed(:read_licenses) }
  end

  describe 'custom dashboard permissions' do
    let(:owner) { create(:user) }
    let(:guest) { create(:user) }
    let(:non_member) { create(:user) }

    before do
      create(:organization_user, :owner, organization: organization, user: owner)
      create(:organization_user, organization: organization, user: guest, access_level: :default)
      stub_licensed_features(product_analytics: true)
      stub_feature_flags(custom_dashboard_storage: true)
    end

    context 'when user is organization owner' do
      subject(:policy) { described_class.new(owner, organization) }

      it { is_expected.to be_allowed(:read_custom_dashboard) }
      it { is_expected.to be_allowed(:create_custom_dashboard) }
    end

    context 'when user is organization member' do
      subject(:policy) { described_class.new(guest, organization) }

      it { is_expected.to be_allowed(:read_custom_dashboard) }
      it { is_expected.to be_disallowed(:create_custom_dashboard) }
    end

    context 'when user is not organization member' do
      subject(:policy) { described_class.new(non_member, organization) }

      it { is_expected.to be_disallowed(:read_custom_dashboard) }
      it { is_expected.to be_disallowed(:create_custom_dashboard) }
    end

    context 'when product analytics is not licensed' do
      subject(:policy) { described_class.new(owner, organization) }

      before do
        stub_licensed_features(product_analytics: false)
      end

      it { is_expected.to be_disallowed(:read_custom_dashboard) }
      it { is_expected.to be_disallowed(:create_custom_dashboard) }
    end

    context 'when feature flag is disabled' do
      subject(:policy) { described_class.new(owner, organization) }

      before do
        stub_feature_flags(custom_dashboard_storage: false)
      end

      it { is_expected.to be_disallowed(:read_custom_dashboard) }
      it { is_expected.to be_disallowed(:create_custom_dashboard) }
    end

    describe 'product_analytics_enabled condition coverage' do
      subject(:policy) { described_class.new(owner, organization) }

      context 'when License.feature_available? returns true' do
        before do
          allow(License)
            .to receive(:feature_available?)
            .with(:product_analytics)
            .and_return(true)
        end

        it 'evaluates condition as true' do
          expect(policy).to be_allowed(:read_custom_dashboard)
        end
      end

      context 'when License.feature_available? returns false' do
        before do
          allow(License)
            .to receive(:feature_available?)
            .with(:product_analytics)
            .and_return(false)
        end

        it 'evaluates condition as false' do
          expect(policy).to be_disallowed(:read_custom_dashboard)
        end
      end
    end
  end
end
