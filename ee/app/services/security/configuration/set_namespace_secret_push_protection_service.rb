# frozen_string_literal: true

module Security
  module Configuration
    class SetNamespaceSecretPushProtectionService
      PROJECTS_BATCH_SIZE = 100
      def initialize(namespace:, enable:, current_user:, excluded_projects_ids: [])
        @namespace = namespace
        @enable = enable
        @current_user = current_user
        @excluded_projects_ids = excluded_projects_ids
      end

      def execute
        return unless valid_request?

        any_updated = false
        ApplicationRecord.transaction do
          projects_scope.each_batch(of: PROJECTS_BATCH_SIZE) do |project_batch|
            updated_count = update_security_setting(project_batch.id_not_in(@excluded_projects_ids))
            any_updated ||= updated_count > 0
          end
          audit if any_updated
        end
        @enable
      end

      protected

      def valid_request?
        @namespace.present? && @current_user.present? && [true, false].include?(@enable)
      end

      def update_security_setting(projects)
        # rubocop:disable CodeReuse/ActiveRecord -- Specific use-case for this service
        updated_records = ProjectSecuritySetting.for_projects(projects.select(:id))
                              .where(pre_receive_secret_detection_enabled: !@enable)
                                .update_all(pre_receive_secret_detection_enabled: @enable,
                                  updated_at: Time.current)
        # rubocop:enable CodeReuse/ActiveRecord

        create_missing_security_setting(projects) + updated_records
      end

      def create_missing_security_setting(projects)
        projects_without_security_setting = projects.without_security_setting
        security_setting_attributes = projects_without_security_setting.map do |project|
          {
            project_id: project.id,
            pre_receive_secret_detection_enabled: @enable,
            updated_at: Time.current
          }
        end
        return 0 unless security_setting_attributes.any?

        ProjectSecuritySetting.upsert_all(security_setting_attributes).length
      end

      def build_audit_context(name:, message:)
        {
          name: name,
          author: @current_user,
          scope: @namespace,
          target: @namespace,
          message: message
        }
      end

      def audit
        raise NotImplementedError
      end

      def projects_scope
        raise NotImplementedError
      end
    end
  end
end
