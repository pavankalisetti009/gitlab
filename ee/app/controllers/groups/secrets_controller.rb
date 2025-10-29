# frozen_string_literal: true

module Groups
  class SecretsController < Groups::ApplicationController
    feature_category :secrets_management
    urgency :low, [:index]

    layout 'group'

    before_action :authorize_view_secrets!
    before_action :check_secrets_enabled!

    private

    def authorize_view_secrets!
      render_404 unless can?(current_user, :reporter_access, group)
    end

    def check_secrets_enabled!
      # TODO: check that secrets manager is provisioned and active
      # https://gitlab.com/gitlab-org/gitlab/-/issues/577453
      render_404 unless Feature.enabled?(:group_secrets_manager, group) &&
        group.licensed_feature_available?(:native_secrets_management)
    end
  end
end
