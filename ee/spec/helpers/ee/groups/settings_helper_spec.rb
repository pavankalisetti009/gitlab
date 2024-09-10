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
          experiment_features_enabled: group.namespace_settings.experiment_features_enabled.to_s,
          are_experiment_settings_allowed: group.experiment_settings_allowed?.to_s,
          redirect_path: edit_group_path(group),
          update_id: group.id })
    end
  end

  describe 'show_group_ai_settings?' do
    using RSpec::Parameterized::TableSyntax
    subject { helper.show_group_ai_settings? }

    where(:ai_chat_enabled, :ai_features_enabled, :result) do
      true  | true  | true
      true  | false | true
      false | true  | true
      false | false | false
    end

    with_them do
      before do
        allow(group).to receive(:licensed_feature_available?).with(:ai_chat).and_return(ai_chat_enabled)
        allow(group).to receive(:licensed_feature_available?).with(:ai_features).and_return(ai_features_enabled)
      end

      it "returns expected result" do
        is_expected.to eq(result)
      end
    end
  end
end
