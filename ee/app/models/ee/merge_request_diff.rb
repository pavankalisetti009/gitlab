# frozen_string_literal: true

module EE
  module MergeRequestDiff
    extend ActiveSupport::Concern

    prepended do
      include ::Geo::ReplicableModel
      include ::Geo::VerifiableModel

      delegate(*::Geo::VerificationState::VERIFICATION_METHODS, to: :merge_request_diff_detail)

      with_replicator ::Geo::MergeRequestDiffReplicator

      has_one :merge_request_diff_detail, autosave: false, inverse_of: :merge_request_diff

      scope :has_external_diffs, -> { with_files.where(stored_externally: true) }
      scope :project_id_in, ->(ids) { where(merge_request_id: ::MergeRequest.where(target_project_id: ids)) }
      scope :available_replicables, -> { has_external_diffs }
      scope :with_verification_state, ->(state) { joins(:merge_request_diff_detail).where(merge_request_diff_details: { verification_state: verification_state_value(state) }) }

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

      def verification_state_object
        merge_request_diff_detail
      end
    end

    class_methods do
      extend ::Gitlab::Utils::Override

      # Search for a list of merge_request_diffs based on the query given in `query`.
      #
      # @param [String] query term that will search over external_diff attribute
      #
      # @return [ActiveRecord::Relation<MergeRequestDiff>] a collection of merge request diffs
      def search(query)
        return all if query.empty?

        where(sanitize_sql_for_conditions({ external_diff: query })).limit(1000)
      end

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

      # @return [ActiveRecord::Relation<MergeRequestDiff>] scope observing selective
      #         sync settings of the given node
      override :selective_sync_scope
      def selective_sync_scope(node, **params)
        replicables = params.fetch(:replicables, all)
        replicables = replicables.primary_key_in(params[:primary_key_in]) if params[:primary_key_in].presence

        return replicables unless node.selective_sync?

        replicables.project_id_in(::Project.selective_sync_scope(node))
      end

      override :verification_state_table_class
      def verification_state_table_class
        MergeRequestDiffDetail
      end
    end

    def merge_request_diff_detail
      super || build_merge_request_diff_detail
    end
  end
end
