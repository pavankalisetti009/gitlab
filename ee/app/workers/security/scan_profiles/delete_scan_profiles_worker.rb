# frozen_string_literal: true

module Security
  module ScanProfiles
    class DeleteScanProfilesWorker
      include ApplicationWorker

      idempotent!
      data_consistency :sticky
      feature_category :security_policy_management
      deduplicate :until_executing, including_scheduled: true

      def perform(scan_profile_ids)
        return unless scan_profile_ids.any?

        scan_profile_ids.each do |scan_profile_id|
          DeleteScanProfileService.execute(scan_profile_id)
        end
      end
    end
  end
end
