# frozen_string_literal: true

module Vulnerabilities
  class ProcessTransferEventsWorker
    include Gitlab::EventStore::Subscriber

    idempotent!
    deduplicate :until_executing, including_scheduled: true
    data_consistency :always

    feature_category :vulnerability_management

    def handle_event(event)
      project_ids(event).each_slice(1_000) { |slice| bulk_schedule_worker(slice) }
    end

    private

    def bulk_schedule_worker(project_ids)
      # rubocop:disable Scalability/BulkPerformWithContext -- allow context omission
      Vulnerabilities::UpdateNamespaceIdsOfVulnerabilityReadsWorker.bulk_perform_async(project_ids.zip)
      # rubocop:enable Scalability/BulkPerformWithContext
    end

    def project_ids(event)
      case event
      when ::Projects::ProjectTransferedEvent
        vulnerable_project_ids(event.data[:project_id])
      when ::Groups::GroupTransferedEvent
        group = Group.find_by_id(event.data[:group_id])

        Gitlab::Database::NamespaceProjectIdsEachBatch.new(
          group_id: group.id,
          resolver: method(:vulnerable_project_ids)
        ).execute
      end
    end

    def vulnerable_project_ids(batch)
      ProjectSetting.for_projects(batch)
                    .has_vulnerabilities
                    .pluck_primary_key
    end
  end
end
