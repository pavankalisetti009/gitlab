# frozen_string_literal: true

module EE
  module Integration
    extend ActiveSupport::Concern

    prepended do
      scope :vulnerability_hooks, -> { where(vulnerability_events: true, active: true) }
    end

    EE_INTEGRATION_NAMES = %w[
      google_cloud_platform_workload_identity_federation
      git_guardian
    ].freeze

    EE_PROJECT_LEVEL_ONLY_INTEGRATION_NAMES = %w[
      github
      google_cloud_platform_artifact_registry
    ].freeze

    GOOGLE_CLOUD_PLATFORM_INTEGRATION_NAMES = %w[
      google_cloud_platform_artifact_registry
      google_cloud_platform_workload_identity_federation
    ].freeze

    class_methods do
      extend ::Gitlab::Utils::Override

      override :integration_names
      def integration_names
        names = super + EE_INTEGRATION_NAMES

        unless ::Gitlab::Saas.feature_available?(:google_cloud_support)
          names.delete('google_cloud_platform_workload_identity_federation')
        end

        names.delete('git_guardian') unless ::Feature.enabled?(:git_guardian_integration)

        names
      end

      override :project_specific_integration_names
      def project_specific_integration_names
        names = super + EE_PROJECT_LEVEL_ONLY_INTEGRATION_NAMES

        unless ::Gitlab::Saas.feature_available?(:google_cloud_support)
          names.delete('google_cloud_platform_artifact_registry')
        end

        names
      end

      # Returns the STI type for the given integration name.
      # Example: "asana" => "Integrations::Asana"
      override :integration_name_to_type
      def integration_name_to_type(name)
        name = name.to_s

        if GOOGLE_CLOUD_PLATFORM_INTEGRATION_NAMES.include?(name)
          name = name.delete_prefix("google_cloud_platform_")
          "Integrations::GoogleCloudPlatform::#{name.camelize}"
        else
          super
        end
      end
    end
  end
end
