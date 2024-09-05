# frozen_string_literal: true

module Projects
  module Security
    class SecretDetectionConfigurationController < Projects::ApplicationController
      include SecurityAndCompliancePermissions

      before_action :check_feature_flag!
      before_action :ensure_feature_is_available!

      feature_category :secret_detection
      urgency :low, [:show]

      def show; end

      def check_feature_flag!
        not_found unless ::Feature.enabled?(:secret_detection_project_level_exclusions, project)
      end

      def ensure_feature_is_available!
        not_found unless project.licensed_feature_available?(:pre_receive_secret_detection)
      end
    end
  end
end
