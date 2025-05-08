# frozen_string_literal: true

module Vulnerabilities
  module NamespaceStatistics
    class ProcessProjectDeleteEventsWorker
      include Gitlab::EventStore::Subscriber

      idempotent!
      data_consistency :sticky
      feature_category :security_asset_inventories

      def handle_event(event)
        project_id = event.data[:project_id]
        group = Group.by_id(event.data[:namespace_id]).first

        return unless project_id && group.present?

        Vulnerabilities::NamespaceStatistics::RecalculateService
          .execute(project_id, group, deleted_project: true)
      end
    end
  end
end
