# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Admin::Menus::AdminOverviewMenu, feature_category: :navigation do
  let(:user) { build_stubbed(:user) }
  let(:context) { Sidebars::Context.new(current_user: user, container: nil) }

  describe '#render' do
    context 'with a regular user' do
      subject(:admin_overview_menu) { described_class.new(context) }

      context 'when user is allowed to access_admin_area' do
        before do
          allow(user).to receive(:can?).and_call_original
          allow(user).to receive(:can?).with(:access_admin_area).and_return(true)
        end

        context 'when custom_ability_read_admin_dashboard FF is enabled' do
          it 'renders' do
            expect(admin_overview_menu.render?).to be(true)
          end
        end

        context 'when custom_ability_read_admin_dashboard FF is disabled' do
          before do
            stub_feature_flags(custom_ability_read_admin_dashboard: false)
          end

          it 'does not render' do
            expect(admin_overview_menu.render?).to be(false)
          end
        end
      end

      context 'when user can not access admin area' do
        it 'does not render' do
          expect(admin_overview_menu.render?).to be(false)
        end
      end
    end
  end
end
