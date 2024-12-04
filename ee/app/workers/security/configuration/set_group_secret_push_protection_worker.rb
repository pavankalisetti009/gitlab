# frozen_string_literal: true

module Security
  module Configuration
    class SetGroupSecretPushProtectionWorker
      include ApplicationWorker

      idempotent!
      data_consistency :sticky
      urgency :high

      feature_category :secret_detection

      # rubocop:disable Lint/UnusedMethodArgument -- Added argument for future development, but it is not yet in use
      # See https://docs.gitlab.com/ee/development/sidekiq/compatibility_across_updates.html#add-an-argument
      def perform(group_id, enable, current_user_id = nil, excluded_projects_ids = [])
        # rubocop:enable Lint/UnusedMethodArgument
        group = Group.find_by_id(group_id)

        return unless group

        SetNamespaceSecretPushProtectionService.execute(namespace: group, enable: enable,
          excluded_projects_ids: excluded_projects_ids)
      end
    end
  end
end
