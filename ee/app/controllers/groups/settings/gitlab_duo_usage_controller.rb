# frozen_string_literal: true

module Groups
  module Settings
    class GitlabDuoUsageController < Groups::ApplicationController
      before_action :authorize_read_usage_quotas!
      before_action :verify_usage_quotas_enabled!

      feature_category :duo_chat

      include ::Nav::GitlabDuoUsageSettingsPage

      before_action do
        push_frontend_feature_flag(:enable_add_on_users_filtering, group)
      end

      def index
        render_404 unless show_gitlab_duo_usage_menu_item?(group)
      end

      private

      def verify_usage_quotas_enabled!
        render_404 unless group.usage_quotas_enabled?
      end
    end
  end
end
