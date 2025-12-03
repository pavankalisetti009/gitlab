# frozen_string_literal: true

module Security
  module ScanProfiles
    class ProcessProjectTransferEventsWorker
      include Gitlab::EventStore::Subscriber

      idempotent!
      data_consistency :sticky
      feature_category :security_asset_inventories

      def handle_event(event)
        return unless event.data[:old_root_namespace_id] != event.data[:new_root_namespace_id]

        project = Project.find_by_id(event.data[:project_id])
        return unless project

        remove_old_namespace_scan_profile_associations(project)
      end

      private

      def remove_old_namespace_scan_profile_associations(project)
        project.security_scan_profiles_projects.not_in_root_namespace(project.group&.root_ancestor).delete_all
      end
    end
  end
end
