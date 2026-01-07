# frozen_string_literal: true

module Security
  module ScanProfiles
    class AttachWorker
      include ApplicationWorker

      data_consistency :sticky
      idempotent!
      deduplicate :until_executed

      concurrency_limit -> { 200 }

      feature_category :security_asset_inventories

      def perform(group_id, scan_profile_id, traverse_hierarchy = true)
        group = Group.find_by_id(group_id)
        return unless group

        scan_profile = Security::ScanProfile.find_by_id(scan_profile_id)
        return unless scan_profile

        Security::ScanProfiles::AttachService.execute(
          group,
          scan_profile,
          traverse_hierarchy: traverse_hierarchy
        )
      end
    end
  end
end
