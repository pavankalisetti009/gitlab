# frozen_string_literal: true

module Security
  module Configuration
    class SetProjectSecretPushProtectionService < SetSecretPushProtectionBaseService
      private

      def projects_scope
        # convert project object into a relation for unified logic in parent class
        Project.id_in(@subject.id)
      end

      def audit
        message = "Secret push protection has been #{@enable ? 'enabled' : 'disabled'}"
        audit_context = build_audit_context(
          name: 'project_security_setting_updated',
          message: message
        )

        ::Gitlab::Audit::Auditor.audit(audit_context)
      end
    end
  end
end
