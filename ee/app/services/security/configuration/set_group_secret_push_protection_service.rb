# frozen_string_literal: true

module Security
  module Configuration
    class SetGroupSecretPushProtectionService < SetSecretPushProtectionBaseService
      private

      def projects_scope
        Project.for_group_and_its_subgroups(@subject)
      end

      def audit
        return unless @subject.is_a?(Group)

        message = build_group_message(fetch_filtered_out_projects)

        audit_context = build_audit_context(
          name: 'group_secret_push_protection_updated',
          message: message
        )

        ::Gitlab::Audit::Auditor.audit(audit_context)
      end

      def fetch_filtered_out_projects
        return [] unless @excluded_projects_ids.present?

        projects_scope.id_in(@excluded_projects_ids).select(:namespace_id, :path).map(&:full_path)
      end

      def build_group_message(filtered_out_projects_full_path)
        message = "Secret push protection has been enabled for group #{@subject.name} and all of its inherited \
groups/projects"

        unless filtered_out_projects_full_path.empty?
          message += " except for #{filtered_out_projects_full_path.join(', ')}"
        end

        message
      end
    end
  end
end
