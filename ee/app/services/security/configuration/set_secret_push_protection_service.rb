# frozen_string_literal: true

module Security
  module Configuration
    class SetSecretPushProtectionService
      def self.execute(current_user:, namespace:, enable:)
        # Some projects do not have the necessary security_setting,
        # so we create it when it is missing
        if namespace.is_a?(Project) && namespace.security_setting.nil?
          namespace.security_setting = ProjectSecuritySetting.new
          namespace.security_setting.save!
        end

        response = ServiceResponse.success(
          payload: {
            enabled: namespace.security_setting.set_pre_receive_secret_detection!(
              enabled: enable
            ),
            errors: []
          })

        if response.success?
          Projects::ProjectSecuritySettingChangesAuditor.new(
            current_user: current_user, model: namespace.security_setting).execute
        end

        response
      rescue StandardError => e
        ServiceResponse.error(
          message: e.message,
          payload: { enabled: nil }
        )
      end
    end
  end
end
