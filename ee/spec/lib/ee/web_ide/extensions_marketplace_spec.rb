# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WebIde::ExtensionsMarketplace, feature_category: :web_ide do
  using RSpec::Parameterized::TableSyntax

  let_it_be_with_reload(:group) { create(:group) }
  let_it_be_with_reload(:current_user) { create(:user) }

  describe '#webide_extensions_gallery_settings' do
    let_it_be(:enabled_expectation) { a_hash_including(enabled: true) }
    let_it_be(:enterprise_disabled_expectation) do
      {
        enabled: false,
        enterprise_group_name: group.full_name,
        enterprise_group_url: ::Gitlab::Routing.url_helpers.group_url(group),
        help_url: a_string_matching('/help/user/project/web_ide/index#extension-marketplace'),
        reason: :enterprise_group_disabled
      }
    end

    subject(:webide_settings) { described_class.webide_extensions_gallery_settings(user: current_user) }

    where(:enterprise_group, :extensions_enabled, :expectation) do
      nil         | false | ref(:enabled_expectation)
      ref(:group) | false | ref(:enterprise_disabled_expectation)
      ref(:group) | true  | ref(:enabled_expectation)
    end

    with_them do
      before do
        stub_feature_flags(
          web_ide_extensions_marketplace: current_user,
          web_ide_oauth: current_user,
          vscode_web_ide: current_user
        )
        current_user.update!(extensions_marketplace_opt_in_status: :enabled, enterprise_group: enterprise_group)
        group.update!(enterprise_users_extensions_marketplace_enabled: extensions_enabled)
      end

      it 'returns expected settings' do
        expect(webide_settings).to match(expectation)
      end
    end
  end
end
