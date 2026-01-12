# frozen_string_literal: true

module Security
  module ScanProfiles
    class DeleteScanProfilesWorker
      include ApplicationWorker

      idempotent!
      data_consistency :sticky
      feature_category :security_policy_management
      deduplicate :until_executing, including_scheduled: true

      # rubocop:disable Lint/UnusedMethodArgument -- Adding a new parameter using multistep release
      # https://gitlab.com/gitlab-org/gitlab/-/merge_requests/217200
      def perform(scan_profile_ids, namespace_id = nil)
        return unless scan_profile_ids.any?

        scan_profile_ids.each do |scan_profile_id|
          DeleteScanProfileService.execute(scan_profile_id)
        end
      end
      # rubocop:enable Lint/UnusedMethodArgument
    end
  end
end
