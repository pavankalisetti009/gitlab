# frozen_string_literal: true

module Security
  module ScanProfiles
    class CleanOldNamespaceConnectionsWorker
      include ApplicationWorker

      idempotent!
      data_consistency :sticky
      feature_category :security_asset_inventories

      def perform(group_id)
        return unless group_id

        CleanOldNamespaceConnectionsService.execute(group_id)
      end
    end
  end
end
