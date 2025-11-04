# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Packages::Maven, feature_category: :virtual_registry do
  describe '.virtual_registry_available?' do
    let_it_be(:group) { create(:group) }
    let_it_be(:user) { create(:user, guest_of: group) }

    subject { described_class.virtual_registry_available?(group, user) }

    before do
      stub_config(dependency_proxy: { enabled: true })
      stub_feature_flags(maven_virtual_registry: true)
      stub_licensed_features(packages_virtual_registry: true)
      allow(VirtualRegistries::Setting).to receive(:find_for_group).with(group).and_return(build_stubbed(
        :virtual_registries_setting, group: group))
    end

    context 'when all conditions are met' do
      it { is_expected.to be(true) }
    end

    context 'when dependency proxy feature is not available' do
      before do
        stub_config(dependency_proxy: { enabled: false })
      end

      it { is_expected.to be(false) }
    end

    context 'when maven_virtual_registry feature flag is disabled' do
      before do
        stub_feature_flags(maven_virtual_registry: false)
      end

      it { is_expected.to be(false) }
    end

    context 'when packages_virtual_registry licensed feature is not available' do
      before do
        stub_licensed_features(packages_virtual_registry: false)
      end

      it { is_expected.to be(false) }
    end

    context 'when user does not have read_virtual_registry permission' do
      let_it_be_with_reload(:user) { create(:user) }

      it { is_expected.to be(false) }
    end

    context 'when virtual registry setting is disabled' do
      before do
        allow(VirtualRegistries::Setting).to receive(:find_for_group).with(group).and_return(build_stubbed(
          :virtual_registries_setting, :disabled, group: group))
      end

      it { is_expected.to be(false) }
    end

    context 'for admin_virtual_registry permission' do
      subject { described_class.virtual_registry_available?(group, user, :admin_virtual_registry) }

      it { is_expected.to be(false) }

      context 'when permission is sufficient' do
        before_all do
          group.add_owner(user)
        end

        it { is_expected.to be(true) }
      end
    end
  end
end
