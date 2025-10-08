# frozen_string_literal: true

module Projects
  class SecretsController < Projects::ApplicationController
    feature_category :secrets_management
    urgency :low, [:index]

    layout 'project'

    before_action :authorize_view_secrets!
    before_action :check_secrets_enabled!

    private

    def authorize_view_secrets!
      render_404 unless can?(current_user, :reporter_access, project)
    end

    def check_secrets_enabled!
      secrets_manager = SecretsManagement::ProjectSecretsManager.find_by_project_id(@project.id)

      render_404 unless
        secrets_manager &&
          Feature.enabled?(:secrets_manager, project) &&
          project.licensed_feature_available?(:native_secrets_management) &&
          secrets_manager.status == SecretsManagement::ProjectSecretsManager::STATUSES[:active]
    end
  end
end
