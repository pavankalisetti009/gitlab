# frozen_string_literal: true

module Security
  module Configuration
    class SetGroupSecretPushProtectionWorker
      include ApplicationWorker

      idempotent!
      data_consistency :sticky
      urgency :high

      feature_category :secret_detection

      def perform(group_id, enable, excluded_projects_ids = [])
        group = Group.find_by_id(group_id)

        return unless group

        SetNamespaceSecretPushProtectionService.execute(namespace: group, enable: enable,
          excluded_projects_ids: excluded_projects_ids)
      end
    end
  end
end
