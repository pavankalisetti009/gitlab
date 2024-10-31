# frozen_string_literal: true

module Groups
  module Settings
    class GitlabDuoController < Groups::ApplicationController
      before_action :authorize_read_usage_quotas!

      feature_category :ai_abstraction_layer

      include ::Nav::GitlabDuoSettingsPage

      def show; end
    end
  end
end
