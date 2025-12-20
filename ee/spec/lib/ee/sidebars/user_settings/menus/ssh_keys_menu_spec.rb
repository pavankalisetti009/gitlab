# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::UserSettings::Menus::SshKeysMenu, feature_category: :navigation do
  subject(:sidebar_item) { described_class.new(context) }

  describe '#render?' do
    context 'for enterprise users', :saas do
      before do
        stub_licensed_features(disable_ssh_keys: true)
        stub_saas_features(disable_ssh_keys: true)
      end

      let_it_be(:group) { create(:group) }
      let_it_be(:user) { create(:enterprise_user, enterprise_group: group) }

      context 'when user is logged in' do
        let(:context) { Sidebars::Context.new(current_user: user, container: nil) }

        it 'renders' do
          expect(sidebar_item.render?).to be true
        end

        context 'when SSH Keys are disabled by the group' do
          before do
            group.namespace_settings.update!(disable_ssh_keys: true)
          end

          it 'does not render' do
            expect(sidebar_item.render?).to be false
          end
        end
      end

      context 'when user is not logged in' do
        let(:context) { Sidebars::Context.new(current_user: nil, container: nil) }

        it 'does not render' do
          expect(sidebar_item.render?).to be false
        end
      end
    end
  end
end
