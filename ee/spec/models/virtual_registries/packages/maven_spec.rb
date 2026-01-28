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

  describe '.log_access_through_project_membership', :request_store do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group:) }
    let_it_be(:user) { create(:user) }

    let(:permission) { :read_virtual_registry }

    subject(:log_access) { described_class.log_access_through_project_membership(group, user) }

    before do
      allow(Gitlab::AppLogger).to receive(:info).and_call_original
      user&.can?(permission, group.virtual_registry_policy_subject)
    end

    context 'when user has project membership' do
      before_all do
        project.add_guest(user)
      end

      it 'logs access' do
        log_access

        expect(Gitlab::AppLogger).to have_received(:info).with(
          hash_including(
            message: 'User granted read_virtual_registry access through project membership',
            user_id: user.id,
            group_id: group.id
          )
        )
      end

      context 'when permission is not :read_virtual_registry' do
        let(:permission) { :create_virtual_registry }

        it 'does not log' do
          log_access

          expect(Gitlab::AppLogger).not_to have_received(:info)
        end
      end

      context 'when checking the virtual registry sidebar menu item' do
        before do
          allow(described_class).to receive(:caller).and_return([
            'ee/app/models/virtual_registries/packages/maven.rb:26:in `virtual_registry_available?`',
            'ee/lib/ee/sidebars/groups/menus/packages_registries_menu.rb:38:in `virtual_registry_available?`',
            'ee/lib/ee/sidebars/groups/menus/packages_registries_menu.rb:22:in `virtual_registry_menu_item`',
            'ee/lib/ee/sidebars/groups/menus/packages_registries_menu.rb:14:in `configure_menu_items`'
          ])
        end

        it 'does not log' do
          log_access

          expect(Gitlab::AppLogger).not_to have_received(:info)
        end
      end
    end

    context 'when user has group membership' do
      before_all do
        group.add_guest(user)
      end

      it 'does not log' do
        log_access

        expect(Gitlab::AppLogger).not_to have_received(:info)
      end
    end

    context 'when user is nil' do
      let(:user) { nil }

      it 'does not log', :aggregate_failures do
        is_expected.to be_nil

        expect(Gitlab::AppLogger).not_to have_received(:info)
      end
    end
  end
end
