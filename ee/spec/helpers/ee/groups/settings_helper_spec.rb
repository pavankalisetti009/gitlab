# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::Groups::SettingsHelper do
  let(:namespace_settings) do
    build(:namespace_settings, unique_project_download_limit: 1,
      unique_project_download_limit_interval_in_seconds: 2,
      unique_project_download_limit_allowlist: %w[username1 username2],
      unique_project_download_limit_alertlist: [3, 4],
      auto_ban_user_on_excessive_projects_download: true)
  end

  let(:group) { build(:group, namespace_settings: namespace_settings) }

  before do
    helper.instance_variable_set(:@group, group)
  end

  describe '.unique_project_download_limit_settings_data', feature_category: :insider_threat do
    subject { helper.unique_project_download_limit_settings_data }

    it 'returns the expected data' do
      is_expected.to eq({ group_full_path: group.full_path,
                          max_number_of_repository_downloads: 1,
                          max_number_of_repository_downloads_within_time_period: 2,
                          git_rate_limit_users_allowlist: %w[username1 username2],
                          git_rate_limit_users_alertlist: [3, 4],
                          auto_ban_user_on_excessive_projects_download: 'true' })
    end
  end

  describe 'group_ai_settings_helper_data' do
    subject { helper.group_ai_settings_helper_data }

    it 'returns the expected data' do
      is_expected.to eq(
        { cascading_settings_data: "{\"locked_by_application_setting\":false,\"locked_by_ancestor\":false}",
          duo_availability: group.namespace_settings.duo_availability.to_s,
          are_duo_settings_locked: group.namespace_settings.duo_features_enabled_locked?.to_s,
          redirect_path: edit_group_path(group),
          update_id: group.id })
    end
  end

  describe 'show_group_ai_settings?' do
    subject { helper.show_group_ai_settings? }

    context 'when feature flag is enabled' do
      before do
        stub_feature_flags(ai_settings_vue_group: true)
      end

      context 'and the user has access to ai chat' do
        before do
          allow(group).to receive(:licensed_feature_available?).with(:ai_chat).and_return(true)
          allow(group).to receive(:licensed_feature_available?).with(:ai_features).and_return(false)
        end

        it 'returns true' do
          is_expected.to be true
        end
      end

      context 'and the user has access to ai features' do
        before do
          allow(group).to receive(:licensed_feature_available?).with(:ai_chat).and_return(false)
          allow(group).to receive(:licensed_feature_available?).with(:ai_features).and_return(true)
        end

        it 'returns true' do
          is_expected.to be true
        end
      end

      context 'and the user does not have access to ai' do
        before do
          allow(group).to receive(:licensed_feature_available?).with(:ai_features).and_return(false)
          allow(group).to receive(:licensed_feature_available?).with(:ai_chat).and_return(false)
        end

        it 'return false' do
          is_expected.to be false
        end
      end

      context 'and the feature flag is disabled' do
        before do
          stub_feature_flags(ai_settings_vue_group: false)
        end

        it 'returns false' do
          is_expected.to be false
        end
      end
    end
  end
end
