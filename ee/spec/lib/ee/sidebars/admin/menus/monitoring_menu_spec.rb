# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Admin::Menus::MonitoringMenu, :enable_admin_mode, feature_category: :navigation do
  subject(:menu) do
    described_class.new(Sidebars::Context.new(current_user: user, container: nil))
  end

  let_it_be(:user, refind: true) { create(:user) }

  describe '#render?' do
    context 'with a non-admin user' do
      before do
        stub_licensed_features(admin_audit_log: true, custom_roles: true)
      end

      it { is_expected.not_to be_render }

      context 'with read_admin_monitoring ability' do
        let_it_be(:membership) { create(:admin_member_role, :read_admin_monitoring, user: user) }

        it { is_expected.to be_render }
      end
    end
  end

  describe "#renderable_items" do
    subject(:menu_items) { menu.renderable_items.map(&:title) }

    context 'with a non-admin user' do
      context "when user has `read_admin_monitoring`" do
        let_it_be(:membership) { create(:admin_member_role, :read_admin_monitoring, user: user) }

        before do
          stub_licensed_features(admin_audit_log: true, custom_roles: true)
        end

        it 'includes the expected menu items' do
          is_expected.to contain_exactly(
            _('Background migrations'),
            _('Health check'),
            _('System information'),
            _('Data management')
          )
        end
      end
    end

    context 'with admin user' do
      let_it_be(:user) { create(:admin) }

      context "when the data_management licensed feature is available" do
        before do
          stub_licensed_features(data_management: true)
        end

        it { is_expected.to include(_('Data management')) }
      end

      context "when the data_management licensed feature is not available" do
        before do
          stub_licensed_features(data_management: false)
        end

        it { is_expected.not_to include(_('Data management')) }
      end
    end
  end
end
