# frozen_string_literal: true

module Packages
  class AuditEventsBaseService
    FEATURE_FLAG_DISABLED_ERROR = ServiceResponse.error(message: 'Feature flag is not enabled').freeze

    def execute
      if ::Feature.disabled?(:package_registry_audit_events, ::Feature.current_request)
        return FEATURE_FLAG_DISABLED_ERROR
      end

      yield

      ServiceResponse.success
    end

    private

    def auth_token_type
      ::Current.token_info&.dig(:token_type) || token_type_from_current_user
    end

    def token_type_from_current_user
      return unless current_user
      return 'DeployToken' if current_user.is_a?(DeployToken)
      return 'CiJobToken' if current_user.from_ci_job_token?

      'PersonalAccessToken'
    end
  end
end
