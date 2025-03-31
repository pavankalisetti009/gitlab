# frozen_string_literal: true

module EE
  module Projects
    module Security
      module ConfigurationPresenter
        extend ::Gitlab::Utils::Override

        override :to_h
        def to_h
          super.merge(vulnerability_archive_export_path: vulnerability_archive_export_path)
        end

        private

        def vulnerability_archive_export_path
          api_v4_security_projects_vulnerability_archive_exports_path(id: project.id)
        end

        override :container_scanning_for_registry_enabled
        def container_scanning_for_registry_enabled
          project_settings&.container_scanning_for_registry_enabled
        end

        override :secret_push_protection_enabled
        def secret_push_protection_enabled
          project_settings&.secret_push_protection_enabled
        end

        override :features
        def features
          super << scan(:container_scanning_for_registry, configured: container_scanning_for_registry_enabled)
        end

        override :secret_detection_configuration_path
        def secret_detection_configuration_path
          project_security_configuration_secret_detection_path(project)
        end
      end
    end
  end
end
