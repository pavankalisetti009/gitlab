# frozen_string_literal: true

module Security
  module AnalyzersStatus
    class ProcessArchivedEventsWorker
      include Gitlab::EventStore::Subscriber

      data_consistency :sticky
      idempotent!
      deduplicate :until_executing, including_scheduled: true

      feature_category :security_asset_inventories

      def handle_event(event)
        project = Project.find_by_id(event.data[:project_id])
        return unless project

        UpdateArchivedService.execute(project)
      end
    end
  end
end
