# frozen_string_literal: true

module Projects
  module Security
    class SecretDetectionConfigurationController < Projects::ApplicationController
      include SecurityAndCompliancePermissions

      before_action :check_feature_flag!
      before_action :ensure_feature_is_available!
      before_action :authorize_read_project_security_exclusions!

      feature_category :secret_detection
      urgency :low, [:show]

      def show; end

      private

      def check_feature_flag!
        not_found unless ::Feature.enabled?(:secret_detection_project_level_exclusions, project)
      end

      def ensure_feature_is_available!
        not_found unless project.licensed_feature_available?(:pre_receive_secret_detection)
      end

      def authorize_read_project_security_exclusions!
        not_found unless can?(current_user, :read_project_security_exclusions, project)
      end
    end
  end
end
