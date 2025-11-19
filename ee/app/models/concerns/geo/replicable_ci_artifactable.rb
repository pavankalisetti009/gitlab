# frozen_string_literal: true

module Geo
  module ReplicableCiArtifactable
    extend ActiveSupport::Concern

    included do
      # On primary, `verifiables` are records that can be checksummed and/or are replicable.
      # On secondary, `verifiables` are records that have already been replicated
      # and (ideally) have been checksummed on the primary
      scope :verifiables, ->(primary_key_in = nil) do
        node = ::GeoNode.current_node

        replicables =
          available_replicables
            .merge(object_storage_scope(node))

        if ::Gitlab::Geo.org_mover_extend_selective_sync_to_primary_checksumming?
          replicables.merge(selective_sync_scope(node, primary_key_in: primary_key_in, replicables: replicables))
        else
          replicables = replicables.primary_key_in(primary_key_in) if primary_key_in
          replicables
        end
      end
    end

    class_methods do
      extend ::Gitlab::Utils::Override

      override :pluck_verifiable_ids_in_range
      def pluck_verifiable_ids_in_range(range)
        verifiables(range).pluck_primary_key
      end

      # @param primary_key_in [Range, Replicable] arg to pass to primary_key_in scope
      # @return [ActiveRecord::Relation<Replicable>] everything that should be synced to this
      #         node, restricted by primary key
      override :replicables_for_current_secondary
      def replicables_for_current_secondary(primary_key_in)
        node = ::Gitlab::Geo.current_node

        replicables = available_replicables.merge(object_storage_scope(node))

        replicables
          .merge(selective_sync_scope(node, primary_key_in: primary_key_in, replicables: replicables))
      end

      # @return [ActiveRecord::Relation<Ci::{PipelineArtifact|JobArtifact|SecureFile}>] scope
      #         observing selective sync settings of the given node
      override :selective_sync_scope
      def selective_sync_scope(node, **params)
        replicables = params.fetch(:replicables, all)
        replicables = replicables.primary_key_in(params[:primary_key_in]) if params[:primary_key_in].presence

        return replicables unless node.selective_sync?

        replicables_project_ids = replicables.distinct.pluck(:project_id) # rubocop:disable Database/AvoidUsingPluckWithoutLimit -- The query is already restricted to a range

        selective_projects_ids  =
          ::Project.selective_sync_scope(node)
            .id_in(replicables_project_ids)
            .pluck_primary_key

        replicables.project_id_in(selective_projects_ids)
      end
    end
  end
end
