# frozen_string_literal: true

module Search
  module Zoekt
    class DeleteProjectWorker
      include ApplicationWorker
      include Search::Worker
      include Gitlab::ExclusiveLeaseHelpers
      prepend ::Geo::SkipSecondary

      TIMEOUT = 1.minute
      MAX_JOBS_PER_HOUR = 3600

      data_consistency :delayed

      urgency :throttled
      idempotent!
      pause_control :zoekt
      concurrency_limit -> { 100 if Feature.enabled?(:zoekt_delete_project_worker_concurrency) } # rubocop:disable Gitlab/FeatureFlagWithoutActor -- global flags

      def perform(root_namespace_id, project_id, node_id = nil)
        return unless ::Search::Zoekt.licensed_and_indexing_enabled?

        nodes = Router.fetch_nodes_for_indexing(project_id, root_namespace_id: root_namespace_id, node_ids: [node_id])

        return false if nodes.empty?

        nodes.each do |n|
          in_lock("#{self.class.name}/#{project_id}/node-#{n.id}", ttl: TIMEOUT, retries: 0) do
            ::Gitlab::Search::Zoekt::Client.delete(node_id: n.id, project_id: project_id)
          end
        end
      end
    end
  end
end
