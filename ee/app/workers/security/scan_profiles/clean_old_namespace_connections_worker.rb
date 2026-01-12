# frozen_string_literal: true

module Security
  module ScanProfiles
    class CleanOldNamespaceConnectionsWorker
      include ApplicationWorker

      idempotent!
      data_consistency :sticky
      feature_category :security_asset_inventories

      # rubocop:disable Lint/UnusedMethodArgument -- Adding a new parameter using multistep release
      # https://gitlab.com/gitlab-org/gitlab/-/merge_requests/217200
      def perform(group_id, traverse_hierarchy = true)
        return unless group_id

        CleanOldNamespaceConnectionsService.execute(group_id)
      end
      # rubocop:enable Lint/UnusedMethodArgument
    end
  end
end
