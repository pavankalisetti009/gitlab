# frozen_string_literal: true

module Security
  module AnalyzersStatus
    class ProcessDeletedEventsWorker
      include Gitlab::EventStore::Subscriber

      idempotent!
      data_consistency :sticky
      feature_category :security_asset_inventories

      def handle_event(event)
        project_id = event.data[:project_id]
        namespace_id = event.data[:namespace_id]

        group = Group.find_by_id(namespace_id)
        return unless project_id && group.present?

        Security::AnalyzerNamespaceStatuses::RecalculateService.execute(project_id, group, deleted_project: true)
      end
    end
  end
end
