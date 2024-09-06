# frozen_string_literal: true

module Groups
  module Settings
    module RemoteDevelopment
      class WorkspacesController < Groups::ApplicationController
        layout 'group_settings'

        before_action :authorize_remote_development!
        before_action :check_agent_authorization_feature_flag!

        feature_category :workspaces
        urgency :low

        def show; end

        private

        def authorize_remote_development!
          render_404 unless can?(current_user, :access_workspaces_feature)
        end

        def check_agent_authorization_feature_flag!
          render_404 unless
            Feature.enabled?(:remote_development_namespace_agent_authorization, @group.root_ancestor)
        end
      end
    end
  end
end
