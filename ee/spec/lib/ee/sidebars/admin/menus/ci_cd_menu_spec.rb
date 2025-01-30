# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Admin::Menus::CiCdMenu, feature_category: :navigation do
  let_it_be(:user) { build_stubbed(:user) }

  let(:context) { Sidebars::Context.new(current_user: user, container: nil) }
  let(:menu) { described_class.new(context) }

  describe '#render?' do
    subject(:render?) { menu.render? }

    before do
      allow(user).to receive(:can?).and_call_original
      allow(user).to receive(:can?).with(:access_admin_area).and_return(can_access_admin_area)
    end

    context 'when user is allowed to access_admin_area' do
      let(:can_access_admin_area) { true }

      context 'when custom_ability_read_admin_cicd FF is enabled' do
        it { is_expected.to be(true) }
      end

      context 'when custom_ability_read_admin_cicd FF is disabled' do
        before do
          stub_feature_flags(custom_ability_read_admin_cicd: false)
        end

        it { is_expected.to be(false) }
      end
    end

    context 'when user is not allowed to access_admin_area' do
      let(:can_access_admin_area) { false }

      it { is_expected.to be(false) }
    end
  end
end
