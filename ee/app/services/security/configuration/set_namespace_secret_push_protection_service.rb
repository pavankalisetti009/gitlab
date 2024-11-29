# frozen_string_literal: true

module Security
  module Configuration
    class SetNamespaceSecretPushProtectionService
      PROJECTS_BATCH_SIZE = 100

      def self.execute(namespace:, enable:, excluded_projects_ids: [])
        return unless namespace
        return unless [true, false].include?(enable)

        ApplicationRecord.transaction do
          if namespace.is_a?(Group)
            Project.for_group_and_its_subgroups(namespace).each_batch(of: PROJECTS_BATCH_SIZE) do |project_batch|
              update_security_setting(project_batch.id_not_in(excluded_projects_ids), enable)
            end
          else
            update_security_setting(Project.id_in(namespace.id).id_not_in(excluded_projects_ids), enable)
          end
        end
      end

      def self.update_security_setting(projects, enable)
        ProjectSecuritySetting.for_projects(projects.select(:id))
                              .update_all(pre_receive_secret_detection_enabled: enable,
                                updated_at: Time.current)

        create_missing_security_setting(projects, enable)
      end

      def self.create_missing_security_setting(projects, enable)
        projects_without_security_setting = projects.without_security_setting
        security_setting_attributes = projects_without_security_setting.map do |project|
          {
            project_id: project.id,
            pre_receive_secret_detection_enabled: enable,
            updated_at: Time.current
          }
        end
        return unless security_setting_attributes.any?

        ProjectSecuritySetting.upsert_all(security_setting_attributes)
      end

      private_class_method :create_missing_security_setting, :update_security_setting
    end
  end
end
