# frozen_string_literal: true

module Packages
  class CreateAuditEventService
    FEATURE_FLAG_DISABLED_ERROR = ServiceResponse.error(message: 'Feature flag is not enabled').freeze

    delegate :project, :creator, to: :package, private: true

    def initialize(package, event_name: 'package_registry_package_published')
      @package = package
      @event_name = event_name
    end

    def execute
      return FEATURE_FLAG_DISABLED_ERROR if ::Feature.disabled?(:package_registry_audit_events, project)

      ::Gitlab::Audit::Auditor.audit(audit_context)

      ServiceResponse.success
    end

    private

    attr_reader :package, :event_name

    def audit_context
      {
        name: event_name,
        author: creator || ::Gitlab::Audit::DeployTokenAuthor.new,
        scope: project.group || project,
        target: package,
        target_details: target_details,
        message: "#{package.package_type.humanize} package published",
        additional_details: { auth_token_type: }
      }
    end

    def target_details
      "#{project.full_path}/#{package.name}-#{package.version}"
    end

    def auth_token_type
      ::Current.token_info&.dig(:token_type) || token_type_from_package_creator
    end

    def token_type_from_package_creator
      return 'DeployToken' unless creator
      return 'CiJobToken' if creator.from_ci_job_token?

      'PersonalAccessToken or CiJobToken'
    end
  end
end
