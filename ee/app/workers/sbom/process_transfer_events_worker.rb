# frozen_string_literal: true

module Sbom
  class ProcessTransferEventsWorker
    include Gitlab::EventStore::Subscriber

    idempotent!
    deduplicate :until_executing, including_scheduled: true
    data_consistency :always

    feature_category :dependency_management

    def handle_event(event)
      args = project_ids(event).zip

      # rubocop:disable Scalability/BulkPerformWithContext -- allow context omission
      ::Sbom::SyncProjectTraversalIdsWorker.bulk_perform_async(args)
      # rubocop:enable Scalability/BulkPerformWithContext
    end

    private

    def project_ids(event)
      case event
      when ::Projects::ProjectTransferedEvent
        project_id = event.data[:project_id]

        return [] unless Sbom::Occurrence.by_project_ids(project_id).exists?

        [project_id]
      when ::Groups::GroupTransferedEvent
        group = Group.find_by_id(event.data[:group_id])

        return [] unless group

        # rubocop:disable CodeReuse/ActiveRecord -- Does not work outside this context.
        exists_subquery = Sbom::Occurrence.where(
          Sbom::Occurrence.arel_table[:project_id].eq(Project.arel_table[:id]))
        # rubocop:enable CodeReuse/ActiveRecord

        group
          .all_project_ids
          .where_exists(exists_subquery)
          .allow_cross_joins_across_databases(url: 'https://gitlab.com/gitlab-org/gitlab/-/issues/472113')
          .pluck_primary_key
      end
    end
  end
end
