# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Packages::Maven, feature_category: :virtual_registry do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user) }

  describe '.virtual_registry_available?' do
    subject { described_class.virtual_registry_available?(group, user) }

    where(:dependency_proxy_enabled, :feature_flag_enabled, :licensed_feature_enabled, :setting_enabled,
      :user_with_access, :expected_result) do
      true  | true  | true  | true  | true  | true
      false | true  | true  | true  | true  | false
      true  | false | true  | true  | true  | false
      true  | true  | false | true  | true  | false
      true  | true  | true  | false | true  | false
      true  | true  | true  | true  | false | false
    end

    with_them do
      let(:stub_setting) do
        build_stubbed(:virtual_registries_setting, enabled: setting_enabled, group: group)
      end

      before do
        stub_config(dependency_proxy: { enabled: dependency_proxy_enabled })
        stub_feature_flags(maven_virtual_registry: feature_flag_enabled)
        stub_licensed_features(packages_virtual_registry: licensed_feature_enabled)
        allow(VirtualRegistries::Setting).to receive(:find_for_group).with(group).and_return(stub_setting)

        group.add_guest(user) if user_with_access # rubocop:disable RSpec/BeforeAllRoleAssignment -- Does not work in before_all
      end

      it { is_expected.to be(expected_result) }
    end
  end

  describe '.feature_enabled?' do
    subject { described_class.feature_enabled?(group) }

    where(:dependency_proxy_enabled, :feature_flag_enabled, :licensed_feature_enabled, :setting_enabled,
      :expected_result) do
      true  | true  | true  | true  | true
      false | true  | true  | true  | false
      true  | false | true  | true  | false
      true  | true  | false | true  | false
      true  | true  | true  | false | false
    end

    with_them do
      let(:stub_setting) do
        build_stubbed(:virtual_registries_setting, enabled: setting_enabled, group: group)
      end

      before do
        stub_config(dependency_proxy: { enabled: dependency_proxy_enabled })
        stub_feature_flags(maven_virtual_registry: feature_flag_enabled)
        stub_licensed_features(packages_virtual_registry: licensed_feature_enabled)
        allow(VirtualRegistries::Setting).to receive(:find_for_group).with(group).and_return(stub_setting)
      end

      it { is_expected.to be(expected_result) }
    end
  end

  describe '.user_has_access?' do
    subject { described_class.user_has_access?(group, user, permission) }

    let_it_be(:user) { create(:user, guest_of: group) }
    let(:permission) { :read_virtual_registry }

    context 'when user has read_virtual_registry permission' do
      it { is_expected.to be(true) }
    end

    context 'when user does not have permission' do
      let_it_be(:user) { create(:user) }

      it { is_expected.to be(false) }
    end

    context 'with admin_virtual_registry permission' do
      let(:permission) { :admin_virtual_registry }

      it { is_expected.to be(false) }

      context 'when user is group owner' do
        before_all do
          group.add_owner(user)
        end

        it { is_expected.to be(true) }
      end
    end
  end
end
